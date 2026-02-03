# syntax=docker/dockerfile:1
# SonarQube: Use specific version tag + COPY instead of ADD
FROM postgres:13-alpine
COPY ./data /var/lib/postgresql/data
EXPOSE 5432