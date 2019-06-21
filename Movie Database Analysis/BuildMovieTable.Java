/*
    Program 3 - Avery Paul Sand <avery.sand@du.edu>
    Read in a Movie Database - MovieLens
    Filter contents into a HBaseTable with relevant Movie Data
 */

import java.io.IOException;
import java.util.ArrayList;

import org.apache.spark.SparkConf;
import org.apache.spark.api.java.JavaPairRDD;
import org.apache.spark.api.java.JavaRDD;
import org.apache.spark.api.java.JavaSparkContext;

import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.hbase.HBaseConfiguration;
import org.apache.hadoop.hbase.client.Put;
import org.apache.hadoop.hbase.io.ImmutableBytesWritable;
import org.apache.hadoop.hbase.mapreduce.TableOutputFormat;
import org.apache.hadoop.mapreduce.Job;
import org.apache.spark.api.java.Optional;
import scala.Tuple2;



public class BuildMovieTable {

    // Global Definitions
    static byte[] INFO_FAMILY = "info".getBytes();
    static byte[] TAG_FAMILY = "tag".getBytes();
    static byte[] RATING_FAMILY = "rating".getBytes();
    static byte[] TITLE_QUALIFIER = "title".getBytes();
    static byte[] GENRES_QUALIFIER = "genres".getBytes();

    /**
     * @param args Command line arguments:
     *             master - specify Spark master
     *             inputDir - specify input directory
     *             tableName - specify output HBase table
     */
    public static void main(String[] args) {

        // Check Arguments
        if (args.length != 3) {
            System.err.println("usage: SparkMaster inputDir tableName");
        }

        // Create a Java Spark Context and HBase Configuration
        SparkConf conf = new SparkConf().setMaster(args[0]).setAppName("BuildMovieTable");
        JavaSparkContext sc = new JavaSparkContext(conf);
        Configuration hConf = HBaseConfiguration.create();

        // Read input files
        String inputDirName = args[1];
        JavaRDD<String> input_tags = sc.textFile(inputDirName + "/tag.csv");
        JavaRDD<String> input_ratings = sc.textFile(inputDirName + "/rating/");
        JavaRDD<String> input_movies = sc.textFile(inputDirName + "/movie.csv");

        // Create HBase Output Table Format
        String outputTableName = args[2];
        Job hOutputJob = null;
        try {
            hOutputJob = Job.getInstance(hConf); //Update to new outfile
            hOutputJob.getConfiguration().set(TableOutputFormat.OUTPUT_TABLE, outputTableName);
            hOutputJob.setOutputFormatClass(TableOutputFormat.class);
        } catch (IOException e) {
            System.err.println("ERROR: Job.getInstance exception: " + e.getMessage());
            System.exit(2);
        }

        // Read "movies.csv" into JavaPairRDD<movieID, Tuple2(title, genre)>
        JavaPairRDD<String, Tuple2<String, String>> movies = input_movies.mapToPair(
                line -> {
                    String[] words = ParseCSV.parseLine(line);
                    String movieID = words[0];
                    String title = words[1];
                    String genres = words[2];
                    return (new Tuple2<>(movieID, new Tuple2<>(title, genres)));
                });

        // Read "tags.csv" into JavaPairRDD<movieId, Tuple2(tagUserID, tag)>
        JavaPairRDD<String, Tuple2<String, String>> tags = input_tags.mapToPair(
                line -> {
                    String[] words = ParseCSV.parseLine(line);
                    String userID = words[0];
                    String movieID = words[1];
                    String tag = words[2] + "|" + words[3]; // tag + "|" + timestamp
                    return (new Tuple2<>(movieID, new Tuple2<>(userID, tag)));
                });

        // Read "ratings.csv" into JavaPairRDD<movieID, Tuple2(ratingUserID, rating)>
        JavaPairRDD<String, Tuple2<String, String>> ratings = input_ratings.mapToPair(
                line -> {
                    String[] words = ParseCSV.parseLine(line);
                    String userID = words[0];
                    String movieID = words[1];
                    String rating = words[2] + "|" + words[3]; // rating + "|" + timestamp
                    return (new Tuple2<>(movieID, new Tuple2<>(userID, rating)));
                });

        // Group By Key
        JavaPairRDD<String, Iterable<Tuple2<String, String>>> tagsGrouped = tags.groupByKey();
        JavaPairRDD<String, Iterable<Tuple2<String, String>>> ratingsGrouped = ratings.groupByKey();

        // Convert from Iterable to ArrayList
        JavaPairRDD<String, ArrayList<Tuple2<String, String>>> tagsList = tagsGrouped.mapValues(
                list -> {
                    ArrayList<Tuple2<String, String>> pairs = new ArrayList<>();
                    for (Tuple2<String, String> tup : list)
                        pairs.add(new Tuple2<>(tup._1, tup._2));
                    return pairs;
                }
        );

        // Convert from Iterable to ArrayList
        JavaPairRDD<String, ArrayList<Tuple2<String, String>>> ratingsList = ratingsGrouped.mapValues(
                list -> {
                    ArrayList<Tuple2<String, String>> pairs = new ArrayList<>();
                    for (Tuple2<String, String> tup : list)
                        pairs.add(new Tuple2<>(tup._1, tup._2));
                    return pairs;
                }
        );

        // Join to form Shape JavaPairRDD<movieID, (Tuple2<title, genres>, ArrayList<Tuple2<userID, tag>>>>
        JavaPairRDD<String, Tuple2<Tuple2<String, String>, Optional<ArrayList<Tuple2<String, String>>>>> moviesPlusTags = movies.leftOuterJoin(tagsList);

        // Join to form Shape JavaPairRDD<movieID, (Tuple2<Tuple2<title, genres>, ArrayList<Tuple2<userID, tag>>, Tuple2<userID, rating>>
        JavaPairRDD<String, Tuple2<Tuple2<Tuple2<String, String>, Optional<ArrayList<Tuple2<String, String>>>>, Optional<ArrayList<Tuple2<String, String>>>>> records
                = moviesPlusTags.leftOuterJoin(ratingsList);

        // Convert to Table Output Format - JavaPairRDD<ImmutableBytesWritable, Put>
        JavaPairRDD<ImmutableBytesWritable, Put> moviesTable = records.sortByKey().mapToPair(
                tuple -> {
                    String movieID = tuple._1;
                    String title = tuple._2._1._1._1;
                    String genres = tuple._2._1._1._2;

                    Put put = new Put(movieID.getBytes());                                          // Row: movieID
                    put.addColumn(INFO_FAMILY, TITLE_QUALIFIER, title.getBytes());                  // info:title
                    put.addColumn(INFO_FAMILY, GENRES_QUALIFIER, genres.getBytes());                // info:genres

                    if ((tuple._2._1._2).isPresent()) {
                        ArrayList<Tuple2<String, String>> tagPairs = new ArrayList<>((tuple._2._1._2).get());   // <userID, tag>
                        for (Tuple2<String, String> tup : tagPairs) {
                            String tagUserID = tup._1;
                            String tag = tup._2;
                            put.addColumn(TAG_FAMILY, tagUserID.getBytes(), tag.getBytes());                     // tag:userID
                        }
                    }

                    if (((tuple._2._2).isPresent())) {
                        ArrayList<Tuple2<String, String>> ratingPairs = new ArrayList<>((tuple._2._2).get());   // <userID, rating>
                        for (Tuple2<String, String> tup : ratingPairs) {
                            String ratingUserID = tup._1;
                            String rating = tup._2;
                            put.addColumn(RATING_FAMILY, ratingUserID.getBytes(), rating.getBytes());           // rating:userID
                        }
                    }

                    return new Tuple2<>(new ImmutableBytesWritable(), put);
                }
        );

        // Write to HBase Table
        moviesTable.saveAsNewAPIHadoopDataset(hOutputJob.getConfiguration());

    }
}
