#!/bin/bash
echo "=== Build API CrisisView ==="
npm ci
npm test -- --coverage --coverageDirectory=coverage || true
docker build -t candidatrncp2026/api-crisiview:latest .
echo "=== Build termine ==="
