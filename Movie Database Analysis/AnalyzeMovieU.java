/*
    Program 3 - Avery Paul Sand <avery.sand@du.edu>
    Read in a Movies HBase table and output per genre statistics for avgRating and numTags
 */

import java.io.IOException;
import java.util.ArrayList;
import java.util.NavigableMap;
import java.util.Collection;
import java.io.Serializable;
import java.text.DecimalFormat;

import org.apache.spark.SparkConf;
import org.apache.spark.api.java.JavaPairRDD;
import org.apache.spark.api.java.JavaRDD;
import org.apache.spark.api.java.JavaSparkContext;
import org.apache.spark.storage.StorageLevel;

import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.hbase.HBaseConfiguration;
import org.apache.hadoop.hbase.client.Put;
import org.apache.hadoop.hbase.client.Result;
import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.hbase.io.ImmutableBytesWritable;
import org.apache.hadoop.hbase.mapreduce.TableInputFormat;
import org.apache.hadoop.mapreduce.Job;

import scala.Tuple2;
import scala.reflect.io.Streamable;


public class AnalyzeMoviesU {

    // Global Definitions
    static byte[] INFO_FAMILY = "info".getBytes();
    static byte[] TAG_FAMILY = "tag".getBytes();
    static byte[] RATING_FAMILY = "rating".getBytes();
    static byte[] TITLE_QUALIFIER = "title".getBytes();
    static byte[] GENRES_QUALIFIER = "genres".getBytes();

    /**
     * @param args Command line arguments:
     *             master - specify Spark master
     *             tableName - specify output HBase table
     *             outputDir - specify output directory
     */
    public static void main(String[] args) {

        // Check Arguments
        if (args.length != 3) {
            System.err.println("usage: SparkMaster tableName outputDir");
        }

        SparkConf conf = new SparkConf().setMaster(args[0]).setAppName("AnalyzeMoviesU");
        JavaSparkContext sc = new JavaSparkContext(conf);

        // Create the HBase configuration
        Configuration hConf = HBaseConfiguration.create();
        String inputTableName = args[1];
        hConf.set(TableInputFormat.INPUT_TABLE, inputTableName);

        // Get an RDD from the HBase table
        JavaPairRDD<ImmutableBytesWritable, Result> tableRDD = sc.newAPIHadoopRDD(hConf, TableInputFormat.class, ImmutableBytesWritable.class, Result.class);

        tableRDD.persist(StorageLevel.MEMORY_ONLY());

        // Transfrom from Table to JavaPairRDD<Genre, Tuple2<ArrayList<Ratings>, numTags>>
        JavaPairRDD<String, Tuple2<ArrayList<Float>, Integer>> genres = tableRDD.flatMapToPair(

                row -> {         // Each input row is Key-Value Pair <movieID, (info:title, info:genres, tag:userID, rating:userID)>

                    // Create Maps For Each Column Family - Shape is NavigableMap<Qualifier, Value>
                    NavigableMap<byte[], byte[]> infoMap = row._2.getFamilyMap(INFO_FAMILY);
                    NavigableMap<byte[], byte[]> tagMap = row._2.getFamilyMap(TAG_FAMILY);
                    NavigableMap<byte[], byte[]> ratingMap = row._2.getFamilyMap(RATING_FAMILY);

                   // Parse Genres into Array
                    String genreArray[] = {""};
                    if (infoMap.containsKey(GENRES_QUALIFIER)){
                        String line = new String (infoMap.get(GENRES_QUALIFIER));
                        genreArray = line.split("\\|");
                    }
                    else {
                        genreArray[0] = "(no genres listed)";
                    }

                    // Gather Number of Tags Per Movie
                    int numTags = tagMap.size();

                    // Gather All Ratings Per Movie
                    Collection<byte[]> byteRatings = ratingMap.values();
                    ArrayList<Float> ratings = new ArrayList<>();
                    for (byte[] rating: byteRatings){
                        String line = new String (rating);
                        String[] words = line.split("\\|"); // rating | timestamp
                        ratings.add(new Float(words[0]));
                    }

                    // For Each Genre Listed For Movie - Add Ratings and numTags
                    ArrayList<Tuple2<String, Tuple2<ArrayList<Float>, Integer>>> genreObjects = new ArrayList<>();
                    for (int i = 0; i < genreArray.length; i++){
                        genreObjects.add(new Tuple2<>(genreArray[i], (new Tuple2<>(ratings, numTags))));
                    }
                    return genreObjects.iterator();
                }
        );


        // Reduce By Key - Merge All Ratings per Genre to one ArrayList and Aggregate numTags
        JavaPairRDD<String, Tuple2<ArrayList<Float>, Integer>> genreData = genres.reduceByKey(
                (movie1, movie2) -> {
                    int numTags = 0;
                    numTags += movie1._2;
                    numTags += movie2._2;
                    ArrayList<Float> ratings = new ArrayList<>();
                    ratings.addAll(movie1._1);
                    ratings.addAll(movie2._1);
                    return (new Tuple2<>(ratings, numTags));
                }
        );

        // Calculate Average Ratings per Key and Transform to Output Format
        JavaPairRDD<String, String> output = genreData.mapToPair(
                genre -> {
                    String genreName = genre._1;
                    int numTags = genre._2._2;

                    // Calculate Total Ratings
                    float totalRatings = 0;
                    ArrayList<Float> ratings = new ArrayList<>(genre._2._1);
                    for (Float rating: ratings){
                        totalRatings += rating;
                    }
                    float avgRating = totalRatings/ratings.size();

                    DecimalFormat df = new DecimalFormat("#.################");
                    String stats = df.format(avgRating) + " " + df.format(numTags);
                    return new Tuple2<>(genreName, stats);
                }
        );

          // Output
          output.sortByKey().saveAsTextFile(args[2]);
    }

}
