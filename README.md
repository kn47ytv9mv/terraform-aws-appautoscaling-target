# terraform-aws-appautoscaling-target

Terraform module for an Application Auto Scaling target and its
policies — the way an ECS service, DynamoDB table, or Aurora replica
set changes capacity in response to load.

## Cost

Scalable targets and policies carry no charge. The capacity they add
does. A target-tracking policy creates CloudWatch alarms on your
behalf, which bill at the standard alarm rate.

## Design

Application Auto Scaling is a separate service from EC2 autoscaling.
For an EC2 autoscaling group, use
[`terraform-aws-autoscaling-policy`](https://github.com/kn47ytv9mv/terraform-aws-autoscaling-policy)
instead — the two do not share resources and are not interchangeable.

The target and its policies are bundled here because a policy cannot
exist without its target, the policies are homogeneous, and nothing
outside references one specifically. Each policy restates the target's
`service_namespace`, `resource_id`, and `scalable_dimension` in AWS's
own model; this module takes them from the target so the caller states
them once.

**A target with no policies registers the resource as scalable and then
never scales it.** That is the most common way this setup silently does
nothing — the target exists, the console shows scaling is configured,
and capacity never moves.

`resource_id` uses each service's own identifier form. For ECS it is
`service/<cluster-name>/<service-name>`, built from
[`terraform-aws-ecs-cluster`](https://github.com/kn47ytv9mv/terraform-aws-ecs-cluster)'s
and
[`terraform-aws-ecs-service`](https://github.com/kn47ytv9mv/terraform-aws-ecs-service)'s
`name` outputs. `scalable_dimension` must belong to the same service as
`service_namespace`, which AWS rejects outright if mismatched.

Each policy's type is inferred from which configuration is supplied —
`target_tracking` or `step_scaling` — rather than making the caller
state it alongside the block that already implies it.

`suspended_state` pauses parts of scaling while leaving the target
registered. Suspending scale-in alone is the usual case during an
incident, so capacity cannot drop while a problem is being investigated.

### Deliberately not covered

Scheduled actions and predictive scaling are separate concerns, and
metric-math queries inside a customized metric specification are not
exposed.

## Usage

```hcl
module "api_scaling" {
  source = "kn47ytv9mv/appautoscaling-target/aws"

  resource_id  = "service/${module.cluster.name}/${module.api.name}"
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
```

Or directly from this repository, scaling a DynamoDB table's reads:

```hcl
module "table_scaling" {
  source = "github.com/kn47ytv9mv/terraform-aws-appautoscaling-target"

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
```

## Requirements

| Name | Version |
|---|---|
| terraform | >= 1.3 |
| aws | ~> 6.61 |

## Providers

| Name | Version |
|---|---|
| aws | ~> 6.61 |

## Inputs

| Name | Description | Default | Required |
|---|---|---|---|
| service_namespace | AWS service whose resource is being scaled (`'ecs'`, `'dynamodb'`, `'rds'`, and others). | `"ecs"` | no |
| resource_id | The resource to scale, in the service's own identifier form. For ECS, `'service/<cluster>/<service>'`. | `null` | no |
| scalable_dimension | The property being scaled. Must match `service_namespace`. | `"ecs:service:DesiredCount"` | no |
| min_capacity | Fewest units maintained. For an ECS service this is the task count. | `null` | no |
| max_capacity | Most units scaling may run up to. | `null` | no |
| role_arn | IAM role application autoscaling assumes. If null, AWS's service-linked role is used. | `null` | no |
| suspended_state | Selectively pauses scaling while leaving the target registered. | `null` | no |
| policies | Scaling policies attached to this target. Each needs exactly one of `target_tracking` or `step_scaling`. | `[]` | no |
| tags | A map of tags to assign to the scalable target. | `null` | no |

## Outputs

| Name | Description |
|---|---|
| id | The ID of the scalable target. |
| arn | The ARN of the scalable target. |
| resource_id | The identifier of the resource being scaled. |
| policy_arns | Map of policy name to its ARN. Feed a step-scaling policy's ARN into a CloudWatch alarm's `alarm_actions`. |

## License

MIT — see [LICENSE.md](LICENSE.md).
