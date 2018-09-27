#!/bin/bash

set -e

if [[ -z $PROJECT_ID || -z $CLUSTER_NAME || -z $CLUSTER_ZONE ]]; then
    echo "PROJECT_ID, CLUSTER_NAME, or CLUSTER_ZONE environment variable is not set"
    echo "  PROJECT_ID = GCP Project Name"
    echo "  CLUSTER_NAME = Name to give the created GKE cluster"
    echo "  CLUSTER_ZONE = Zone to create the cluster in (ex. 'us-east1-b')"
    exit 1
fi

echo "Creating GKE Cluster $CLUSTER_NAME in $CLUSTER_ZONE in project $PROJECT_ID"
gcloud container clusters create $CLUSTER_NAME \
  --zone=$CLUSTER_ZONE \
  --cluster-version=latest \
  --machine-type=n1-standard-4 \
  --enable-autoscaling --min-nodes=1 --max-nodes=10 \
  --enable-autorepair \
  --scopes=service-control,service-management,compute-rw,storage-ro,cloud-platform,logging-write,monitoring-write,pubsub,datastore \
  --num-nodes=3

kubectl create clusterrolebinding cluster-admin-binding \
--clusterrole=cluster-admin \
--user=$(gcloud config get-value core/account)

echo "Installing Istio"
kubectl apply -f https://storage.googleapis.com/knative-releases/serving/latest/istio.yaml
kubectl label namespace default istio-injection=enabled

echo "Installing Knative Build"
kubectl apply -f https://storage.googleapis.com/knative-releases/build/latest/release.yaml

echo "Installing Knative Serving"
kubectl apply -f https://storage.googleapis.com/knative-releases/serving/latest/release.yaml

echo "Installing Knative Eventing"
kubectl apply -f https://storage.googleapis.com/knative-releases/eventing/latest/release.yaml

echo "Downloading Riff CLI"
wget https://github.com/projectriff/riff/releases/download/v0.1.0/riff-darwin-amd64.tgz -O /tmp/riff-darwin-amd64.tgz
tar -xf /tmp/riff-darwin-amd64.tgz -C /tmp

echo "Initalizing Namespace"
/tmp/riff namespace init default --secret push-credentials

echo ""
echo "Riff CLI downloaded to: /tmp/riff"
echo "Copy to your \$PATH if needed"

echo ""
echo "To get the cluster IP, run:"
echo ""
echo "export SERVICE_IP=\`kubectl get svc knative-ingressgateway -n istio-system -o jsonpath=\"{.status.loadBalancer.ingress[*].ip}\"\`"