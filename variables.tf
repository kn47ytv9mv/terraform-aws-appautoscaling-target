variable "service_namespace" {
  default     = "ecs"
  description = "AWS service whose resource is being scaled ('ecs', 'dynamodb', 'rds', 'lambda', 'elasticache', and others). Defaults to 'ecs', the common case in this family."
}

variable "resource_id" {
  default     = null
  description = "The resource to scale, in the service's own identifier form. For ECS this is 'service/<cluster-name>/<service-name>' — built from terraform-aws-ecs-cluster's and terraform-aws-ecs-service's name outputs. For a DynamoDB table it is 'table/<table-name>'."
}

variable "scalable_dimension" {
  default     = "ecs:service:DesiredCount"
  description = "The property being scaled (e.g. 'ecs:service:DesiredCount', 'dynamodb:table:ReadCapacityUnits'). Must match service_namespace — AWS rejects a dimension belonging to a different service."
}

variable "min_capacity" {
  default     = null
  description = "Fewest units application autoscaling maintains. For an ECS service this is the task count, and setting 0 lets the service scale to nothing at all."
}

variable "max_capacity" {
  default     = null
  description = "Most units application autoscaling may run up to."
}

variable "role_arn" {
  default     = null
  description = "ARN of an IAM role application autoscaling assumes. If null, AWS uses the service-linked role it creates automatically, which is correct for every standard case."
}

variable "suspended_state" {
  default     = null
  description = "Selectively pauses parts of scaling while leaving the target registered. Suspending scale-in alone is the usual case during an incident, so capacity cannot drop while a problem is being investigated."
  type = object({
    dynamic_scaling_in_suspended  = optional(bool)
    dynamic_scaling_out_suspended = optional(bool)
    scheduled_scaling_suspended   = optional(bool)
  })
}

variable "policies" {
  default     = []
  description = "Scaling policies attached to this target. Each needs a name and either target_tracking or step_scaling. A target with no policies registers the resource as scalable and then never scales it, which is the most common way this setup silently does nothing."
  type = list(object({
    name = string
    target_tracking = optional(object({
      target_value           = number
      predefined_metric_type = optional(string)
      resource_label         = optional(string)
      scale_in_cooldown      = optional(number)
      scale_out_cooldown     = optional(number)
      disable_scale_in       = optional(bool)
      customized_metric = optional(object({
        metric_name = string
        namespace   = string
        statistic   = string
        unit        = optional(string)
        dimensions  = optional(map(string), {})
      }))
    }))
    step_scaling = optional(object({
      adjustment_type          = string
      cooldown                 = optional(number)
      metric_aggregation_type  = optional(string)
      min_adjustment_magnitude = optional(number)
      step_adjustments = list(object({
        scaling_adjustment          = number
        metric_interval_lower_bound = optional(string)
        metric_interval_upper_bound = optional(string)
      }))
    }))
  }))

  validation {
    condition     = alltrue([for p in var.policies : (p.target_tracking == null) != (p.step_scaling == null)])
    error_message = "Each policy needs exactly one of target_tracking or step_scaling."
  }

  validation {
    condition = alltrue([
      for p in var.policies :
      p.target_tracking == null || (p.target_tracking.predefined_metric_type == null) != (p.target_tracking.customized_metric == null)
    ])
    error_message = "A target-tracking policy needs exactly one of predefined_metric_type or customized_metric."
  }
}

variable "tags" {
  default     = null
  description = "A map of tags to assign to the scalable target."
}
