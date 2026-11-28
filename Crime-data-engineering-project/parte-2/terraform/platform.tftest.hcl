mock_provider "aws" {}

run "contrato_da_av2" {
  command = plan

  assert {
    condition = (
      var.raw_bucket_name == "eda262-g04-lake-raw"
      && var.trusted_bucket_name == "eda262-g04-lake-trusted"
      && var.refined_bucket_name == "eda262-g04-lake-refined"
    )
    error_message = "Os buckets das três camadas não seguem o contrato da AV2."
  }

  assert {
    condition     = output.query_target_bytes == 1048576 && output.query_cutoff_bytes == 10485760
    error_message = "A meta ou o teto de custo diverge das decisões."
  }

  assert {
    condition     = toset(output.years) == toset(["2024", "2025", "2026"])
    error_message = "As partições anuais estão incompletas."
  }
}
