/**
 * Avery Paul Sand
 * Program 2 - Stocks
 * Reads in two input files: Company Fundamentals and Stock Prices
 * Calculates Statistics on the Prices and then joins both datasets and performs further Statistics
 */

import java.lang.Double;
import java.lang.String;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;

import org.apache.spark.SparkConf;
import org.apache.spark.api.java.JavaSparkContext;
import org.apache.spark.api.java.JavaRDD;
import org.apache.spark.api.java.JavaPairRDD;
import org.apache.spark.storage.StorageLevel;
import org.apache.spark.util.LongAccumulator;

import scala.Tuple2;

public class SparkStocks {

    // Helper Functions
    static public double getMean(Iterable<Double> list){
        double size = 0.0, sum = 0.0;

        for (Double share : list){
            if (share <= 0.0){
                continue;
            }
            else{
                sum += share;
                size++;
            }
        }
        return (sum / size);
    }

    // Overloaded for Computing Valuation Variance
    static public double getMean(Iterable<Double> list, Double shares_outstanding){
        double size = 0.0, sum = 0.0;

        for (Double share : list){
            if (share <= 0.0){
                continue;
            }
            else{
                sum += (share * shares_outstanding);
                size++;
            }
        }
        return (sum / size);
    }

    static public double getMin(Iterable<Double> list){
        double min = Double.MAX_VALUE;

        for (Double share : list){
            if (share <= 0.0){
                continue;
            }
            else{
                if (share < min){
                    min = share;
                }
            }
        }
        return min;
    }

    static public double getMax(Iterable<Double> list){
        double max = Double.MIN_VALUE;

        for (Double share : list){
            if (share <= 0.0){
                continue;
            }
            else{
                if (share > max){
                    max = share;
                }
            }
        }
        return max;
    }

    static public double getVariance(Iterable<Double> list){
        double size = 0.0, sum = 0.0;
        double mean = getMean(list);
        for (Double share : list){
            if (share <= 0.0){
                continue;
            }
            else{
                sum += Math.pow((share - mean), 2);
                size++;
            }
        }
        return ((1 / size) * sum);
    }

    // Overloaded for Computing Valuation Variance
    static public double getVariance(ArrayList<Double> list, double shares_outstanding){
        double size = 0.0, sum = 0.0;
        double mean = getMean(list, shares_outstanding);
        for (Double share : list){
            if (share <= 0.0){
                continue;
            }
            else{
                sum += Math.pow(((share * shares_outstanding) - mean), 2);
                size++;
            }
        }
        return ((1 / size) * sum);
    }


    /*
     *  Specify four arguments:
     *    master - specify Spark master ("local" or "spark-yarn")
     *    prices_input - specify prices input file
     *    fundamentals_input - specify fundamentals input file
     *    output - specify output file
     */
    public static void main(String[] args) {

    // Check arguments
        if (args.length != 4) {
        System.err.println("usage: master prices_input fundamentals_input output ");
        System.exit(1);
    }

    // Create a Java Spark Context and load input data
    SparkConf conf = new SparkConf().setMaster(args[0]).setAppName("SparkStocks");
    JavaSparkContext sc = new JavaSparkContext(conf);
    JavaRDD<String> input_prices = sc.textFile(args[1]);
    JavaRDD<String> input_fundamentals = sc.textFile(args[2]);

    // Accumulators for Logging # Records Read per Input File and Incomplete("Missing") Records
    final LongAccumulator pricesAcc = sc.sc().longAccumulator("Read prices");
    final LongAccumulator fundamentalAcc = sc.sc().longAccumulator("Read Fundamental");
    final LongAccumulator missingFundamentalsAcc = sc.sc().longAccumulator("Missing Fundamentals");
    final LongAccumulator missingPricesAcc = sc.sc().longAccumulator("Missing Prices");

    // Filter Prices CSV into JavaPairRDD<Ticker Symbol, Closing Value>
    JavaPairRDD<String, Double> price_pairs = input_prices.flatMapToPair(
            line -> {
                    pricesAcc.add(1);
                    ArrayList<Tuple2<String,Double>> pair  = new ArrayList<>();
                    String[] words = line.split(",");
                    String ticker_symbol = words[1];
                    double close = Double.parseDouble(words[3]);
                    pair.add(new Tuple2<>(ticker_symbol, close));
                    return pair.iterator();
            });

    // Group All Pairs of Prices by Key - JavaPairRDD<Ticker Symbol, Iterable<Closing Values>>
    JavaPairRDD<String, Iterable <Double>> prices = price_pairs.groupByKey();

    // Sort By Key and Translate to - JavaPairRDD<Ticker Symbol, ArrayList<Closing Values>>
    JavaPairRDD<String, ArrayList<Double>> sortedPrices = prices.mapValues(
            list -> {
                ArrayList<Double> prices_sorted = new ArrayList<>();
                for (Double d : list)
                    prices_sorted.add(d);
                Collections.sort(prices_sorted);
                return prices_sorted;
            }
    );

    // Calculate Price Statistics - <Ticker Symbol, (pMean, pMin, pMax, pVar)>
    JavaPairRDD<String, ArrayList<Float>> price_stats = sortedPrices.flatMapValues(
            list -> {
                ArrayList<Float> stats = new ArrayList<>();
                stats.add((float)getMean(list));
                stats.add((float)getMin(list));
                stats.add((float)getMax(list));
                stats.add((float)getVariance(list));
                return Arrays.asList(stats);
            }
    );


    // Filter Fundamentals CSV into - JavaPairRDD<Ticker Symbol, Shares Outstanding>
    JavaPairRDD<String, Double> fundamentals_pairs = input_fundamentals.flatMapToPair(
            line -> {
                fundamentalAcc.add(1);
                ArrayList<Tuple2<String,Double>> pair  = new ArrayList<>();
                String[] words = line.split(",");
                String ticker_symbol = words[1];
                double shares_outstanding;
                if (words.length < 79 || Double.parseDouble(words[78]) <= 0.0){ // Missing or incomplete data
                    shares_outstanding = 0.0;
                }
                else{
                    shares_outstanding = Double.parseDouble(words[78]);
                }
                pair.add(new Tuple2<>(ticker_symbol, shares_outstanding));
                return pair.iterator();
            });

    // Group by Key and Change to Shape - JavaPairRDD<Ticker Symbol, Mean Shares Outstanding>
    JavaPairRDD<String, Double> fundamentals = fundamentals_pairs.groupByKey().flatMapValues(
            list -> {
                ArrayList<Double> means = new ArrayList<>();
                double mean = getMean(list);
                if (Double.isNaN(mean)){ // Incomplete Fundamentals Field, Track with Accumulator
                    missingFundamentalsAcc.add(1);
                }
                means.add(mean);
                return means;
            }
    ).filter(entry -> !Double.isNaN(entry._2)); // Filter Out Incomplete Records

    // Persist RDDs
    fundamentals.persist(StorageLevel.MEMORY_ONLY());
    sortedPrices.persist(StorageLevel.MEMORY_ONLY());

    // Join Prices and Fundamentals into JavaPairRDD<Ticker Symbol, Tuple2<ArrayList<Closing Values>, Mean Shares Outstanding>>
    JavaPairRDD<String, Tuple2<ArrayList<Double>, Double>> records = sortedPrices.join(fundamentals);
    records.persist(StorageLevel.MEMORY_ONLY());

    // Calculate Missing Records from Both Datasets
    JavaPairRDD<String, ArrayList<Double>> missing_prices = sortedPrices.subtractByKey(fundamentals);
    JavaPairRDD<String, Double> missing_fundamentals = fundamentals.subtractByKey(sortedPrices);

    // Calculate Valuation Statistics - Shape <Ticker Symbol, (vMean, vMin, vMax, vVar)>
    JavaPairRDD<String, ArrayList<Float>> valuation_stats = records.flatMapValues(

            (tuple) -> { // Tuple2<Close, Mean Shares Outstanding>
                ArrayList<Float> stats = new ArrayList<>();
                ArrayList<Double> closing_prices = tuple._1;
                double shares_outstanding = tuple._2;

                stats.add((float) (getMean(closing_prices) * shares_outstanding));
                stats.add((float) (getMin(closing_prices) * shares_outstanding));
                stats.add((float) (getMax(closing_prices) * shares_outstanding));
                stats.add((float) getVariance(closing_prices, shares_outstanding));

                return Arrays.asList(stats);
            }
    );

    // Combine both Valuation and Prices Statistics RDDs into  - JavaPairRDD<Ticker Symbol, ArrayList<pMean, pMin, pMax, pVariance, vMean, vMin, vMax, vVariance>>>
    JavaPairRDD<String, ArrayList<Float>> stats = price_stats.union(valuation_stats).reduceByKey(
            (prices_list, valuations_list) -> {
                ArrayList<Float> vals = new ArrayList<>();
                if (prices_list.size() != 4){ //Incomplete Prices Field, Track with Accumulator
                    missingPricesAcc.add(1);
                }
                vals.add(prices_list.get(0)); //Price Mean
                vals.add(prices_list.get(1)); //Price Min
                vals.add(prices_list.get(2)); //Price Max
                vals.add(prices_list.get(3)); //Price Variance
                vals.add(valuations_list.get(0)); //Valuation Mean
                vals.add(valuations_list.get(1)); //Valuation Min
                vals.add(valuations_list.get(2)); //Valuation Max
                vals.add(valuations_list.get(3)); //Valuation Variance
                return vals;
            }
    ).filter(entry -> (entry._2.size() == 8)); // Filter Out Incomplete Records

    // Convert Statistics RDD to Type String for Printing <Ticker Symbol, Statistics>
    JavaPairRDD<String, String> stats_string = stats.flatMapToPair(
            tup -> {
                ArrayList<Tuple2<String,String>> statistics_string = new ArrayList<>();

                String formatted_stats = tup._2.toString()
                        .replace(",", "")  //remove the commas
                        .replace("[", "")  //remove the right bracket
                        .replace("]", "");  //remove the left bracket

                statistics_string.add(new Tuple2<>(tup._1, formatted_stats));
                return statistics_string.iterator();
            }
    );

    // Write Results to File, and Print Counters to Standard Out
    stats_string.sortByKey().saveAsTextFile(args[3]);
    System.out.println(">> Missing price tickers: " + (missing_prices.count() + missingPricesAcc.value()));
    System.out.println(">> Missing fundamentals tickers: " + (missing_fundamentals.count() + missingFundamentalsAcc.value()));
    System.out.println(">> Stock price records read: " + pricesAcc.value());
    System.out.println(">> Fundamentals records read: " + fundamentalAcc.value());

    }

}
