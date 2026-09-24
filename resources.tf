resource "aws_appautoscaling_target" "resource" {
  service_namespace  = var.service_namespace
  resource_id        = var.resource_id
  scalable_dimension = var.scalable_dimension

  min_capacity = var.min_capacity
  max_capacity = var.max_capacity
  role_arn     = var.role_arn

  dynamic "suspended_state" {
    for_each = var.suspended_state[*]

    content {
      dynamic_scaling_in_suspended  = suspended_state.value.dynamic_scaling_in_suspended
      dynamic_scaling_out_suspended = suspended_state.value.dynamic_scaling_out_suspended
      scheduled_scaling_suspended   = suspended_state.value.scheduled_scaling_suspended
    }
  }

  tags = var.tags
}

resource "aws_appautoscaling_policy" "resource" {
  for_each = { for p in var.policies : p.name => p }

  name               = each.value.name
  service_namespace  = aws_appautoscaling_target.resource.service_namespace
  resource_id        = aws_appautoscaling_target.resource.resource_id
  scalable_dimension = aws_appautoscaling_target.resource.scalable_dimension
  policy_type        = each.value.target_tracking != null ? "TargetTrackingScaling" : "StepScaling"

  dynamic "target_tracking_scaling_policy_configuration" {
    for_each = each.value.target_tracking[*]

    content {
      target_value       = target_tracking_scaling_policy_configuration.value.target_value
      scale_in_cooldown  = target_tracking_scaling_policy_configuration.value.scale_in_cooldown
      scale_out_cooldown = target_tracking_scaling_policy_configuration.value.scale_out_cooldown
      disable_scale_in   = target_tracking_scaling_policy_configuration.value.disable_scale_in

      dynamic "predefined_metric_specification" {
        for_each = target_tracking_scaling_policy_configuration.value.predefined_metric_type[*]

        content {
          predefined_metric_type = predefined_metric_specification.value
          resource_label         = target_tracking_scaling_policy_configuration.value.resource_label
        }
      }

      dynamic "customized_metric_specification" {
        for_each = target_tracking_scaling_policy_configuration.value.customized_metric[*]

        content {
          metric_name = customized_metric_specification.value.metric_name
          namespace   = customized_metric_specification.value.namespace
          statistic   = customized_metric_specification.value.statistic
          unit        = customized_metric_specification.value.unit

          dynamic "dimensions" {
            for_each = customized_metric_specification.value.dimensions

            content {
              name  = dimensions.key
              value = dimensions.value
            }
          }
        }
      }
    }
  }

  dynamic "step_scaling_policy_configuration" {
    for_each = each.value.step_scaling[*]

    content {
      adjustment_type          = step_scaling_policy_configuration.value.adjustment_type
      cooldown                 = step_scaling_policy_configuration.value.cooldown
      metric_aggregation_type  = step_scaling_policy_configuration.value.metric_aggregation_type
      min_adjustment_magnitude = step_scaling_policy_configuration.value.min_adjustment_magnitude

      dynamic "step_adjustment" {
        for_each = step_scaling_policy_configuration.value.step_adjustments

        content {
          scaling_adjustment          = step_adjustment.value.scaling_adjustment
          metric_interval_lower_bound = step_adjustment.value.metric_interval_lower_bound
          metric_interval_upper_bound = step_adjustment.value.metric_interval_upper_bound
        }
      }
    }
  }
}

output "id" {
  description = "The ID of the scalable target."
  value       = aws_appautoscaling_target.resource.id
}

output "arn" {
  description = "The ARN of the scalable target."
  value       = aws_appautoscaling_target.resource.arn
}

output "resource_id" {
  description = "The identifier of the resource being scaled."
  value       = aws_appautoscaling_target.resource.resource_id
}

output "policy_arns" {
  description = "Map of policy name to its ARN, one entry per entry in policies. Feed a step-scaling policy's ARN into a CloudWatch alarm's alarm_actions — unlike target tracking, step scaling fires from an alarm rather than managing its own."
  value       = { for k, p in aws_appautoscaling_policy.resource : k => p.arn }
}
