# Troubleshooting

## Common Issues

### Spark driver crashes
Check logs: kubectl logs -n streaming cdc-streaming-process-driver

### No data in Iceberg
Verify Kafka topics have data and Spark streaming is running.

### Out of memory
Use smaller preset: ./scripts/start.sh barebones
