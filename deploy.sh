#!/bin/bash

#Step 1 - build docker images
cd build/blue_machine || exit 1


if docker build -t 'sprhoto/blue_machine:latest' .; then
true
else 
  echo "Build failed for blue machine."
  exit 1
fi

cd ../red_machine || exit 1

if docker build -t 'sprhoto/red_machine:latest' .; then
true
else 
  echo "Build failed for red machine."
  exit 1
fi

#Step 2 - push images

if docker login; then
true
else
  echo "Docker login failed."
  exit 1
fi

if docker push 'sprhoto/blue_machine:latest'; then
true
else
  echo "Docker push of blue machine failed."
  exit 1
fi

if docker push 'sprhoto/red_machine:latest'; then
true
else
  echo "Docker push of red machine failed."
  exit 1
fi

#Step 3 validate and deploy terraform
cd ../../infrastructure || exit 1

if terraform init; then
true
else
  echo "Terraform init failed."
  exit 1
fi

if terraform validate; then
true
else
  echo "Terraform validate failed."
  exit 1
fi

if terraform plan; then
true
else
  echo "Terraform plan failed."
  exit 1
fi

if terraform apply -auto-approve; then
true
else
  echo "Terraform apply failed."
  exit 1
fi

#Step 4: check health of alb

alb_healthy=0
alb_name=$(terraform output alb_arn | sed s/\"//g)
echo "Waiting on load balancer $alb_name to become active"
while [ $alb_healthy -lt 1 ]; do
  for i in $(aws elbv2 describe-load-balancers --load-balancer-arns "$alb_name" | jq '.LoadBalancers[].State.Code' | sed s/\"//g); do
    if [ "$i" == "active" ]; then
      echo "LB is active"
      alb_healthy=$((alb_healthy+1))
    fi
  done
  sleep 1
done 

target_healthy=0
target_group=$(terraform output target_group_arn | sed s/\"//g)
echo "Waiting on a members of target group $target_group to become healthy"
while [ $target_healthy -lt 1 ]; do
  number_healthy=0
  for i in $(aws elbv2 describe-target-health --target-group-arn "$target_group" | jq '.TargetHealthDescriptions[].TargetHealth.State' | sed s/\"//g); do
    if [ "$i" == "healthy" ]; then
      number_healthy=$((number_healthy+1))
    fi
  done
  if [ $number_healthy -eq 2 ]; then
    target_healthy=$((target_healthy+1))
    echo "All members healthy"
  fi
done 

