/*
 *  Lab5 - Baseball Hall of Fame filtering from HBase data
 *
 * Avery Paul Sand <avery.sand@du.edu>
 */

import java.io.IOException;
import java.io.Serializable;
import java.util.NavigableMap;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Iterator;

import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.hbase.HBaseConfiguration;
import org.apache.hadoop.hbase.client.Put;
import org.apache.hadoop.hbase.client.Result;
import org.apache.hadoop.hbase.io.ImmutableBytesWritable;
import org.apache.hadoop.hbase.mapreduce.TableInputFormat;
import org.apache.hadoop.hbase.mapreduce.TableOutputFormat;
import org.apache.hadoop.mapreduce.Job;

import org.apache.spark.SparkConf;
import org.apache.spark.api.java.JavaPairRDD;
import org.apache.spark.api.java.JavaSparkContext;
import org.apache.spark.storage.StorageLevel;
import org.apache.spark.api.java.function.PairFlatMapFunction;

import scala.Tuple2;



/**
 * HBaseball
 * <p>
 * Scan HBase table and output all data
 */
public class HBaseball {

    //byte arrays of relevant family and qualifier names
    static byte[] PLAYER_FAMILY = "Players".getBytes();
    static byte[] HALL_OF_FAME_FAMILY = "HallOfFame".getBytes();
    static byte[] HOF_FAMILY = "HOF".getBytes();
    static byte[] YEAR_ID_QUALIFIER = "yearid".getBytes();
    static byte[] INDUCTED_QUALIFIER = "inducted".getBytes();
    static byte[] NAME_FIRST_QUALIFIER = "nameFirst".getBytes();
    static byte[] NAME_LAST_QUALIFIER = "nameLast".getBytes();
    static byte[] NAME_FULL_QUALIFIER = "nameFull".getBytes();
    static byte[] CATEGORY_QUALIFIER = "category".getBytes();

    /**
     * @param args Command line arguments:
     *             master - specify Spark master
     *             input - specify input HBase table
     *             output - specify output HBase table
     */
    public static void main(String[] args) {

        // Check args
        if (args.length != 3) {
            System.err.println("usage: SparkMaster inputTable outputTable");
        }

        // Create a Java Spark Context
        SparkConf conf = new SparkConf().setMaster(args[0]).setAppName("HBaseball");
        JavaSparkContext sc = new JavaSparkContext(conf);

        // Create the HBase configuration
        Configuration hConf = HBaseConfiguration.create();
        String inputTableName = args[1];
        String outputTableName = args[2];
        hConf.set(TableInputFormat.INPUT_TABLE, inputTableName);

        // Get an RDD from the HBase table
        JavaPairRDD<ImmutableBytesWritable, Result> tableRDD = sc.newAPIHadoopRDD(hConf, TableInputFormat.class, ImmutableBytesWritable.class, Result.class);

        // Persist the input RDD since we're using multiple operations
        tableRDD.persist(StorageLevel.MEMORY_ONLY());

        System.out.println(">> Table size = " + tableRDD.count());

        //Create Hadoop API config to write back to HBase table
        Job hOutputJob = null;
        try {
            hOutputJob = Job.getInstance(hConf); //Update to new outfile
            hOutputJob.getConfiguration().set(TableOutputFormat.OUTPUT_TABLE, outputTableName);
            hOutputJob.setOutputFormatClass(TableOutputFormat.class);
        } catch (IOException e) {
            System.err.println("ERROR: Job.getInstance exception: " + e.getMessage());
            System.exit(2);
        }

        //Filter rows to isolate players in the Hall of Fame and save specific attributes into JavaPairRDD
        JavaPairRDD<ImmutableBytesWritable, Put> hallOfFame = tableRDD.flatMapValues(
                result -> {
                        // Shape is <Qualifier, Value>
                        NavigableMap<byte[], byte[]> playerMap = result.getFamilyMap(PLAYER_FAMILY);
                        NavigableMap<byte[], byte[]> hallOfFameMap = result.getFamilyMap(HALL_OF_FAME_FAMILY);
                        String firstName = "", lastName = "", fullName = "", yearID = "", category = "";
                        ArrayList<Put> puts = new ArrayList<>();


                        if (hallOfFameMap.containsKey(INDUCTED_QUALIFIER) && hallOfFameMap.get(INDUCTED_QUALIFIER)[0] == 'Y' && hallOfFameMap.containsKey(YEAR_ID_QUALIFIER)) { //Player is in Hall Of Fame

                            firstName = new String(playerMap.get(NAME_FIRST_QUALIFIER));
                            lastName = new String(playerMap.get(NAME_LAST_QUALIFIER));
                            fullName = firstName + " " + lastName;
                            yearID = new String(hallOfFameMap.get(YEAR_ID_QUALIFIER));
                            category = new String(hallOfFameMap.get(CATEGORY_QUALIFIER));

                            Put put = new Put(result.getRow()); // Key is unique playerID
                            put.addColumn(HOF_FAMILY, CATEGORY_QUALIFIER, category.getBytes()); //category
                            put.addColumn(HOF_FAMILY, NAME_FULL_QUALIFIER, fullName.getBytes()); //full name
                            put.addColumn(HOF_FAMILY, YEAR_ID_QUALIFIER, yearID.getBytes()); //year inducted
                            puts.add(put);
                        }
                        return puts;

                });

        //convert JavaPairRDD to HBase format and write to output
        hallOfFame.saveAsNewAPIHadoopDataset(hOutputJob.getConfiguration());

    }

}

