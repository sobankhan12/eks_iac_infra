
// resource "aws_wafv2_web_acl" "main" {
//   name        = var.waf_name
//   description = "AWS managed rules."
//   scope       = var.waf_scope

//   default_action {
//     block {}
//   }
//   rule {
//     name     = "AWSManagedRulesCommonRuleSet"
//     priority = 10

//     statement {
//       managed_rule_group_statement {
//         name        = "AWSManagedRulesCommonRuleSet"
//         vendor_name = "AWS"
//         rule_action_override {
//           action_to_use {
//             allow {}
//           }
//           name = "SizeRestrictions_QUERYSTRING"
//         }
//       }
//     }

//     visibility_config {
//       cloudwatch_metrics_enabled = true
//       metric_name                = "AWSManagedRulesCommonRuleSetMetric"
//       sampled_requests_enabled   = true
//     }
//   }


//   rule {
//     name     = "AWSManagedRulesKnownBadInputsRuleSet"
//     priority = 20

//     override_action {
//       count {}
//     }

//     statement {
//       managed_rule_group_statement {
//         name        = "AWSManagedRulesKnownBadInputsRuleSet"
//         vendor_name = "AWS"
//       }
//     }

//     visibility_config {
//       cloudwatch_metrics_enabled = true
//       metric_name                = "AWSManagedRulesKnownBadInputsRuleSetMetric"
//       sampled_requests_enabled   = true
//     }
//   }

//   rule {
//     name     = "AWSManagedRulesLinuxRuleSet"
//     priority = 30

//     override_action {
//       count {}
//     }

//     statement {
//       managed_rule_group_statement {
//         name        = "AWSManagedRulesLinuxRuleSet"
//         vendor_name = "AWS"
//       }
//     }

//     visibility_config {
//       cloudwatch_metrics_enabled = true
//       metric_name                = "AWSManagedRulesLinuxRuleSetMetric"
//       sampled_requests_enabled   = true
//     }
//   }
//   rule {
//     name     = "AWSManagedRulesAnonymousIpList"
//     priority = 40

//     override_action {
//       count {}
//     }

//     statement {
//       managed_rule_group_statement {
//         name        = "AWSManagedRulesAnonymousIpList"
//         vendor_name = "AWS"
//       }
//     }

//     visibility_config {
//       cloudwatch_metrics_enabled = true
//       metric_name                = "AWSManagedRulesAnonymousIpListMetric"
//       sampled_requests_enabled   = true
//     }
//   }
//   rule {
//     name     = "AWSManagedRulesAmazonIpReputationList"
//     priority = 50

//     override_action {
//       count {}
//     }

//     statement {
//       managed_rule_group_statement {
//         name        = "AWSManagedRulesAmazonIpReputationList"
//         vendor_name = "AWS"
//         rule_action_override {
//           action_to_use {
//             allow {}
//           }
//           name = "AWSManagedIPDDoSList"
//         }   
//       }
//     }

//     visibility_config {
//       cloudwatch_metrics_enabled = true
//       metric_name                = "AWSManagedRulesAmazonIpReputationListMetric"
//       sampled_requests_enabled   = true
//     }
//   }
//   rule {
//     name     = "AWSManagedRulesSQLiRuleSet"
//     priority = 60

//     override_action {
//       count {}
//     }

//     statement {
//       managed_rule_group_statement {
//         name        = "AWSManagedRulesSQLiRuleSett"
//         vendor_name = "AWS"
//       }
//     }

//     visibility_config {
//       cloudwatch_metrics_enabled = true
//       metric_name                = "AWSManagedRulesSQLiRuleSet"
//       sampled_requests_enabled   = true
//     }
//   }
//    visibility_config {
//     cloudwatch_metrics_enabled = true
//     metric_name                = "ExternalACL"
//     sampled_requests_enabled   = true
//   }

// }

resource "aws_wafv2_web_acl" "main" {
  name        = var.waf_name
  description = "AWS Managed Rules."
  scope       = var.waf_scope

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 10

    override_action {
      count {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        rule_action_override {
          action_to_use {
            count {}
          }

          name = "SizeRestrictions_QUERYSTRING"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "AWSManagedRulesCommonRuleSetMetric"
      sampled_requests_enabled   = false
    }
  }

  rule {
    name     = "AWSManagedRulesAmazonIpReputationList"
    priority = 20

    override_action {
      count {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"

        rule_action_override {
          action_to_use {
            count {}
          }

          name = "AWSManagedIPDDoSList"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "AWSManagedRulesAmazonIpReputationListMetric"
      sampled_requests_enabled   = false
    }
  }

  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 30

    override_action {
      count {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"

      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "AWSManagedRulesSQLiRuleSetMetric"
      sampled_requests_enabled   = false
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 40

    override_action {
      count {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"

      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "AWSManagedRulesKnownBadInputsRuleSet"
      sampled_requests_enabled   = false
    }
  }

  rule {
    name     = "AWSManagedRulesLinuxRuleSet"
    priority = 50

    override_action {
      count {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesLinuxRuleSet"
        vendor_name = "AWS"

      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "AWSManagedRulesLinuxRuleSet"
      sampled_requests_enabled   = false
    }
  }

  rule {
    name     = "AWSManagedRulesAnonymousIpList"
    priority = 60

    override_action {
      count {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAnonymousIpList"
        vendor_name = "AWS"
        rule_action_override {
          action_to_use {
            count {}
          }

          name = "HostingProviderIPList"
        }

      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "AWSManagedRulesAnonymousIpList"
      sampled_requests_enabled   = false
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "ExternalAcl"
    sampled_requests_enabled   = true
  }
}
