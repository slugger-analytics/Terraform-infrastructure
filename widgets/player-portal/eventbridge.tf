# EventBridge Scheduled Rule — Player Portal TBC Sync
# Invokes player-portal-sync Lambda every 30 minutes to pull fresh data from
# The Baseball Cube feeds (transactions, batting, pitching) and upsert into Aurora.

resource "aws_cloudwatch_event_rule" "sync_schedule" {
  name                = "player-portal-sync"
  description         = "Triggers the Player Portal TBC feed sync every 30 minutes"
  schedule_expression = "rate(30 minutes)"
  tags                = local.tags
}

resource "aws_cloudwatch_event_target" "sync" {
  rule      = aws_cloudwatch_event_rule.sync_schedule.name
  target_id = "PlayerPortalSyncLambda"
  arn       = aws_lambda_function.sync.arn
}

resource "aws_lambda_permission" "eventbridge_sync" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sync.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.sync_schedule.arn
}
