name := "streaming-processor"

version := "0.1.0"

scalaVersion := "2.12.18"

val sparkVersion = "3.5.0"
val icebergVersion = "1.5.0"

libraryDependencies ++= Seq(
  "org.apache.spark" %% "spark-core" % sparkVersion % "provided",
  "org.apache.spark" %% "spark-sql" % sparkVersion % "provided",
  "org.apache.spark" %% "spark-sql-kafka-0-10" % sparkVersion,
  "org.apache.iceberg" %% "iceberg-spark-runtime-3.5_2.12" % icebergVersion,
  "org.apache.iceberg" %% "iceberg-kafka" % icebergVersion,
  "org.apache.hadoop" % "hadoop-aws" % "3.3.4",
  "com.amazonaws" % "aws-java-sdk-bundle" % "1.12.666"
)

assembly / assemblyMergeStrategy := {
  case PathList("META-INF", xs @ _*) => MergeStrategy.discard
  case x => MergeStrategy.first
}
