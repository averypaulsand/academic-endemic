# Projects
These are a few projects I coded for 3000-level courses while studying at the University of Denver in 2019


## Movie Database Analysis:
Performed updates to an HBase movie database using Spark in a small distributed cluster. Read in csv files containing 20,000 movie entries from a Hadoop filesystem to create the database and then aggregated movie entries into per genre statistics. Coded in Java with reliance on Scala’s tuple library and Linux shell scripts to update and run remotely.  

## Process Scheduler
A round-robin multi-process scheduler built for any Operating System. Coded in C++

## Stock Aggregation
Read in company fundamentals and stock prices from separate CSV text files and group each by key with statistical aggregations on specific attributes. Then join both RDDs by Ticker Symbol to create an RDD for further statistical operations. Finally, output results using accumulators to log metadata. Coded in Java using Apache Spark
