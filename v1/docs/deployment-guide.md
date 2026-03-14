# Deployment Guide

## Prerequisites
- Kubernetes cluster (k3d, minikube, kind)
- kubectl configured
- helm 3.x installed

## Quick Start

1. Check system capacity:
   ./scripts/check-capacity.sh

2. Deploy:
   ./scripts/start.sh minimal

3. Verify:
   ./scripts/verify-stack.sh
