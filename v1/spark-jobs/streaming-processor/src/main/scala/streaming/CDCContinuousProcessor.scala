package streaming

import org.apache.spark.sql.SparkSession
import org.apache.spark.sql.functions._
import org.apache.spark.sql.types._
import org.apache.spark.sql.streaming.Trigger

object CDCContinuousProcessor {
  def main(args: Array[String]): Unit = {
    val spark = SparkSession.builder()
      .appName("CDC Continuous Streaming Processor")
      .config("spark.sql.streaming.schemaInference", "true")
      .getOrCreate()

    import spark.implicits._

    val kafkaBootstrapServers = sys.env.getOrElse("KAFKA_BOOTSTRAP_SERVERS", "kafka:9092")

    // Read sales CDC from Kafka
    val salesRaw = spark.readStream
      .format("kafka")
      .option("kafka.bootstrap.servers", kafkaBootstrapServers)
      .option("subscribe", "mysql-cdc.appdb.sales")
      .option("startingOffsets", "earliest")
      .load()

    val sales = salesRaw
      .select(from_json($"value".cast("string"),
        StructType(Seq(
          StructField("after", StringType, nullable = true)
        ))).as("data"))
      .select($"data.after")
      .as[String]

    // Write to Iceberg
    val query = sales.writeStream
      .format("iceberg")
      .outputMode("append")
      .trigger(Trigger.Continuous("1 second"))
      .option("checkpointLocation", "/checkpoints/sales-raw")
      .foreachBatch { (batchDF: org.apache.spark.sql.DataFrame, batchId: Long) =>
        batchDF.write
          .format("iceberg")
          .mode("append")
          .save("lakekeeper.demo.sales_raw")
      }
      .start()

    query.awaitTermination()
  }
}
