---
name: aws-cost-check
description: Comprehensive AWS account cost audit — discovers all active resources, checks for runaway costs, and flags free tier limits
disable-model-invocation: true
---

# AWS Cost Check

Perform a thorough cost and health audit of an AWS account. Discovers all active services and
resources, checks for runaway costs or loops, flags resources approaching free tier limits, and
provides a full cost breakdown.

This is a **generic, discovery-driven** audit — it does not assume any particular application
architecture. It inspects whatever is running in the account.

## Input

`<args>` may contain:

- **Optional:** An AWS profile name. If not provided, check the repo's CLAUDE.md for an
  `## AWS Cost Check` section that specifies a default profile. If no repo-level config exists
  either, fall back to the AWS CLI default profile (no `--profile` flag).
- **Optional:** A time window like `24h`, `7d`, `mtd` (default: `mtd` = month-to-date).

Examples:

- `/aws-cost-check` — month-to-date audit with the repo-configured or default AWS profile
- `/aws-cost-check 24h` — last 24 hours
- `/aws-cost-check my-profile 7d` — custom profile, last 7 days
- `/aws-cost-check mtd` — explicit month-to-date

## Prerequisites

- The `aws` CLI must be installed and the profile must be authenticated.
- The profile needs read access to Cost Explorer, CloudWatch, and the ability to list resources
  (Lambda, DynamoDB, SQS, SNS, S3, etc.).
- **Repo-level configuration:** Repos can define an `## AWS Cost Check` section in their CLAUDE.md
  to specify a default profile, authentication method (SSO vs static credentials), and alternative
  profiles for resource enumeration. Always check CLAUDE.md before falling back to defaults.
- **Region:** Resource enumeration (Lambda, DynamoDB, etc.) is per-region. This audit uses the
  profile's configured default region. Cost Explorer is global and covers all regions. If the user
  has resources in multiple regions, note this limitation in the summary.

## Steps

### 1. Check repo configuration and authenticate

First, determine the profile to use:

1. If a profile was specified in `<args>`, use that.
2. Otherwise, check the repo's CLAUDE.md for an `## AWS Cost Check` section with a default profile.
3. If neither exists, use the AWS CLI default profile (no `--profile` flag).

Verify credentials:

```sh
aws sts get-caller-identity --profile <profile>
```

If this fails with a credentials error:

- **SSO profiles:** Run `aws sso login --profile <profile>` and wait for the user to complete the
  browser login, then retry `get-caller-identity`.
- **Static credentials:** Inform the user that credentials are not configured and ask how they'd
  like to authenticate.

Print the account ID, assumed role, and default region so the user knows which account and region are
being audited.

### 2. Cost Explorer — top-level billing

Fetch the month-to-date (or specified window) cost breakdown by service:

```sh
aws ce get-cost-and-usage --profile <profile> \
  --time-period Start=<start>,End=<end> \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --output json
```

Parse results and present a table sorted by cost descending. Include:

- Service name
- Cost ($)
- % of total

Also fetch the **daily trend** for the window to detect spikes:

```sh
aws ce get-cost-and-usage --profile <profile> \
  --time-period Start=<start>,End=<end> \
  --granularity DAILY \
  --metrics UnblendedCost \
  --output json
```

Flag any day where cost is **> 2x the average** of the other days.

### 3. Discover active resources

Enumerate what's actually running in the account. For each service below, list resources and collect
metrics. **Skip services that return empty results** — only report on what exists.

#### 3a. Lambda functions

```sh
aws lambda list-functions --profile <profile> \
  --query 'Functions[].{Name:FunctionName,Runtime:Runtime,Memory:MemorySize,Timeout:Timeout}' \
  --output json
```

For each function, fetch from CloudWatch over the time window:

- **Invocations** (Sum)
- **Errors** (Sum)
- **Duration** (Average, in ms)
- **Throttles** (Sum)

Calculate for each function:

- Error rate = Errors / Invocations * 100
- GB-seconds = Invocations * AvgDuration_sec * Memory_MB / 1024

**Free tier comparison** (always-free after 12 months is NOT available; 12-month free tier):

- 1,000,000 requests/month
- 400,000 GB-seconds/month

Sum all functions and show % of free tier consumed. Flag if **> 80%**.

#### 3b. DynamoDB tables

```sh
aws dynamodb list-tables --profile <profile> --output json
```

For each table, get billing mode and metrics:

```sh
aws dynamodb describe-table --profile <profile> --table-name <table> \
  --query 'Table.{BillingMode:BillingModeSummary.BillingMode,ItemCount:ItemCount,TableSizeBytes:TableSizeBytes}'
```

CloudWatch metrics per table:

- **ConsumedReadCapacityUnits** (Sum)
- **ConsumedWriteCapacityUnits** (Sum)
- **ThrottledRequests** (Sum)
- **SystemErrors** (Sum)

Estimate cost:

- On-demand: $1.25/1M write request units, $0.25/1M read request units
- Storage: $0.25/GB/month

**Free tier:** 25 RCU + 25 WCU always-free (provisioned mode only), 25 GB storage always-free.

Flag any **throttled requests > 0** or **system errors > 0**.

#### 3c. SQS queues

```sh
aws sqs list-queues --profile <profile> --output json
```

For each queue, check depth:

```sh
aws sqs get-queue-attributes --profile <profile> --queue-url <url> \
  --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible \
    ApproximateNumberOfMessagesDelayed
```

Flag any queue with **> 0 messages** (especially DLQs — queues with "dead-letter" or "dlq" in the
name).

**Free tier:** 1,000,000 requests/month (always-free).

#### 3d. SNS topics

```sh
aws sns list-topics --profile <profile> --output json
```

Check CloudWatch for publish volume:

```sh
aws cloudwatch get-metric-statistics --profile <profile> \
  --namespace AWS/SNS --metric-name NumberOfMessagesPublished \
  --dimensions Name=TopicName,Value=<topic> \
  --start-time <start> --end-time <now> \
  --period <window-seconds> --statistics Sum
```

**Free tier:** 1,000,000 publishes/month, 100,000 HTTP/S deliveries (always-free).

#### 3e. API Gateway

```sh
aws apigateway get-rest-apis --profile <profile> --output json 2>/dev/null
aws apigatewayv2 get-apis --profile <profile> --output json 2>/dev/null
```

If APIs exist, check invocation counts via CloudWatch (`AWS/ApiGateway`, metric `Count`).

**Free tier:** 1,000,000 REST API calls/month for 12 months.

#### 3f. S3 buckets

```sh
aws s3api list-buckets --profile <profile> --output json
```

For each bucket, check size via CloudWatch:

```sh
aws cloudwatch get-metric-statistics --profile <profile> \
  --namespace AWS/S3 --metric-name BucketSizeBytes \
  --dimensions Name=BucketName,Value=<bucket> Name=StorageType,Value=StandardStorage \
  --start-time <2-days-ago> --end-time <now> \
  --period 86400 --statistics Average
```

**Free tier:** 5 GB storage, 20,000 GET, 2,000 PUT for 12 months.

#### 3g. Bedrock (AI/ML)

```sh
aws cloudwatch list-metrics --profile <profile> \
  --namespace AWS/Bedrock --metric-name Invocations \
  --query 'Metrics[].Dimensions'
```

If Bedrock metrics exist, for each model:

- **Invocations** (Sum)
- **InputTokenCount** (Sum) — if available
- **OutputTokenCount** (Sum) — if available
- **InvocationLatency** (Average)

Estimate cost based on model pricing:

| Model | Input ($/1M tokens) | Output ($/1M tokens) |
| --- | --- | --- |
| Claude Haiku 3.5/4.5 | $0.80 | $4.00 |
| Claude Sonnet 3.5/4 | $3.00 | $15.00 |
| Claude Opus 4 | $15.00 | $75.00 |

If token counts aren't available, estimate ~1K input + ~300 output tokens per invocation.

**Free tier:** None for Bedrock. Flag this prominently if invocations exist.

#### 3h. EventBridge

```sh
aws events list-rules --profile <profile> --output json
```

List rules with their schedules and targets. Check for rules firing at unexpectedly high frequency.

**Free tier:** All state change events free. Custom events and partner events $1.00/1M.

#### 3i. CloudWatch Logs

```sh
aws cloudwatch get-metric-statistics --profile <profile> \
  --namespace AWS/Logs --metric-name IncomingBytes \
  --start-time <start> --end-time <now> \
  --period <window-seconds> --statistics Sum
```

**Free tier:** 5 GB ingestion, 5 GB storage, 5 GB scanned for 12 months. Always-free: 10 custom
metrics, 10 alarms.

Flag if ingestion is **> 4 GB/month** (approaching 5 GB limit).

#### 3j. Route 53

```sh
aws route53 list-hosted-zones --profile <profile> --output json
```

Each hosted zone costs $0.50/month. No free tier for hosted zones.

#### 3k. CloudWatch Alarms

```sh
aws cloudwatch describe-alarms --profile <profile> \
  --query 'MetricAlarms[].{Name:AlarmName,State:StateValue}' --output json
```

Check for any alarms in **ALARM** state — these indicate active problems.

**Free tier:** 10 alarms always-free.

#### 3l. EC2 / ECS / EKS / RDS

Quick check for running compute that might be burning money:

```sh
aws ec2 describe-instances --profile <profile> \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].{Id:InstanceId,Type:InstanceType,LaunchTime:LaunchTime}' \
  --output json

aws ecs list-clusters --profile <profile> --output json
aws rds describe-db-instances --profile <profile> \
  --query 'DBInstances[].{Id:DBInstanceIdentifier,Class:DBInstanceClass,Status:DBInstanceStatus}' \
  --output json 2>/dev/null
```

Flag any **running EC2 instances**, active ECS clusters, or RDS instances — these are typically the
most expensive resources.

### 4. Free tier dashboard

Compile a summary table of all services with free tier limits:

| Service | Free Tier Limit | Your Usage | % Used | Status |
| --- | --- | --- | --- | --- |
| Lambda Requests | 1M/month | X | Y% | OK/WARN/OVER |
| Lambda Compute | 400K GB-sec | X | Y% | OK/WARN/OVER |
| ... | ... | ... | ... | ... |

Status levels:

- **OK** — < 50% of free tier
- **WATCH** — 50-80% of free tier
- **WARN** — > 80% of free tier
- **OVER** — exceeding free tier
- **N/A** — no free tier for this service

### 5. Anomaly detection

Flag anything unusual:

- **Runaway loops:** Any Lambda with > 10,000 invocations/day without a clear schedule-based reason
- **Error storms:** Any resource with > 20% error rate
- **DLQ buildup:** Any DLQ with growing message count
- **Throttling:** Any DynamoDB throttles or Lambda throttles
- **Idle expensive resources:** Running EC2/RDS/ECS with zero or near-zero utilization
- **Cost spikes:** Any day with cost > 2x the average
- **Alarms firing:** Any CloudWatch alarm in ALARM state

### 6. Print summary

Present the results in clear sections:

1. **Account Info** — account ID, profile, time window
2. **Cost Overview** — total MTD spend, daily average, projected monthly total
3. **Cost by Service** — table sorted by cost descending
4. **Daily Trend** — flag any cost spikes
5. **Resource Details** — per-service tables (only for services with active resources)
6. **Free Tier Status** — dashboard table with % used and status
7. **Alerts** — any warnings, ordered by severity:
   - 🔴 Critical: runaway costs, ALARM state, throttling
   - 🟡 Warning: approaching free tier limits, error rates > 10%, DLQ buildup
   - 🟢 OK: everything within normal parameters
8. **Estimated Cost Without Free Tier** — what the bill would be at full pricing, so the user
   understands their actual resource consumption
