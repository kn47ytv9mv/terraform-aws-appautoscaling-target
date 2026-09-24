mock_provider "aws" {}

run "a_policy_needs_exactly_one_configuration" {
  command = plan

  variables {
    resource_id  = "service/prod/api"
    min_capacity = 1
    max_capacity = 10
    policies = [
      { name = "cpu" },
    ]
  }

  expect_failures = [var.policies]
}

run "target_tracking_needs_exactly_one_metric_source" {
  command = plan

  variables {
    resource_id  = "service/prod/api"
    min_capacity = 1
    max_capacity = 10
    policies = [
      {
        name = "cpu"
        target_tracking = {
          target_value           = 60
          predefined_metric_type = "ECSServiceAverageCPUUtilization"
          customized_metric = {
            metric_name = "QueueDepth"
            namespace   = "App"
            statistic   = "Average"
          }
        }
      },
    ]
  }

  expect_failures = [var.policies]
}

run "defaults_target_an_ecs_service" {
  command = plan

  variables {
    resource_id  = "service/prod/api"
    min_capacity = 1
    max_capacity = 10
  }

  assert {
    condition     = aws_appautoscaling_target.resource.service_namespace == "ecs"
    error_message = "The namespace should default to ECS, the common case in this family."
  }

  assert {
    condition     = aws_appautoscaling_target.resource.scalable_dimension == "ecs:service:DesiredCount"
    error_message = "The scalable dimension should default to an ECS service's task count."
  }
}

run "no_policies_by_default" {
  command = plan

  variables {
    resource_id  = "service/prod/api"
    min_capacity = 1
    max_capacity = 10
  }

  assert {
    condition     = length(aws_appautoscaling_policy.resource) == 0
    error_message = "Leaving policies unset should create none, registering the target without scaling it."
  }
}

run "policies_create_one_resource_each_with_the_right_type" {
  command = apply

  variables {
    resource_id  = "service/prod/api"
    min_capacity = 1
    max_capacity = 10
    policies = [
      {
        name = "cpu"
        target_tracking = {
          target_value           = 60
          predefined_metric_type = "ECSServiceAverageCPUUtilization"
        }
      },
      {
        name = "queue-steps"
        step_scaling = {
          adjustment_type = "ChangeInCapacity"
          step_adjustments = [
            { scaling_adjustment = 1, metric_interval_lower_bound = "0" },
          ]
        }
      },
    ]
  }

  assert {
    condition     = length(aws_appautoscaling_policy.resource) == 2
    error_message = "Each policies entry should create one policy resource."
  }

  assert {
    condition     = aws_appautoscaling_policy.resource["cpu"].policy_type == "TargetTrackingScaling"
    error_message = "A policy with target_tracking should be typed as target tracking, without the caller stating it."
  }

  assert {
    condition     = aws_appautoscaling_policy.resource["queue-steps"].policy_type == "StepScaling"
    error_message = "A policy with step_scaling should be typed as step scaling."
  }
}

run "policies_inherit_the_targets_identity" {
  command = apply

  variables {
    resource_id  = "service/prod/api"
    min_capacity = 1
    max_capacity = 10
    policies = [
      {
        name            = "cpu"
        target_tracking = { target_value = 60, predefined_metric_type = "ECSServiceAverageCPUUtilization" }
      },
    ]
  }

  assert {
    condition     = aws_appautoscaling_policy.resource["cpu"].resource_id == "service/prod/api"
    error_message = "A policy should take its resource identity from the target rather than making the caller repeat it."
  }
}

run "suspended_state_creates_one_block" {
  command = plan

  variables {
    resource_id     = "service/prod/api"
    min_capacity    = 1
    max_capacity    = 10
    suspended_state = { dynamic_scaling_in_suspended = true }
  }

  assert {
    condition     = one(aws_appautoscaling_target.resource.suspended_state).dynamic_scaling_in_suspended == true
    error_message = "Suspending scale-in should pass through, so capacity cannot drop during an incident."
  }
}

run "readme_default_example" {
  command = plan

  variables {
    resource_id  = "service/prod/api"
    min_capacity = 2
    max_capacity = 20

    policies = [
      {
        name = "cpu"
        target_tracking = {
          target_value           = 60
          predefined_metric_type = "ECSServiceAverageCPUUtilization"
          scale_in_cooldown      = 300
          scale_out_cooldown     = 60
        }
      },
    ]
  }
}

run "readme_dynamodb_example" {
  command = plan

  variables {
    service_namespace  = "dynamodb"
    resource_id        = "table/orders"
    scalable_dimension = "dynamodb:table:ReadCapacityUnits"

    min_capacity = 5
    max_capacity = 100

    policies = [
      {
        name = "reads"
        target_tracking = {
          target_value           = 70
          predefined_metric_type = "DynamoDBReadCapacityUtilization"
        }
      },
    ]
  }
}
