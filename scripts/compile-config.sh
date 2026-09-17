#!/usr/bin/env bash
set -euo pipefail
if [[ $# != 3 ]]; then
  echo 'Usage: compile-config.sh SOURCE_DIRECTORY NEW_OUTPUT_DIRECTORY PLATFORM_AC_FILE' >&2
  exit 2
fi
source_dir="$(cd "$1" && pwd)"
access_control="$(cd "$(dirname "$3")" && pwd)/$(basename "$3")"
output_parent="$(cd "$(dirname "$2")" && pwd)"
output_dir="$output_parent/$(basename "$2")"
cd "$(dirname "$0")/.."
mvn -B -ntp -pl corelia-config-compiler -am -DskipTests package org.apache.maven.plugins:maven-dependency-plugin:3.7.0:build-classpath \
  -DincludeScope=runtime -Dmdep.outputFile=target/compiler.classpath
classpath="corelia-config-compiler/target/classes:$(cat corelia-config-compiler/target/compiler.classpath)"
exec java -cp "$classpath" ru.corelia.configuration.ConfigurationCompiler "$source_dir" "$output_dir" 0.1.0 "$access_control"
