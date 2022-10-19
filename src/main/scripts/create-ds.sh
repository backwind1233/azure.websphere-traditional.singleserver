#!/bin/sh

#      Copyright (c) Microsoft Corporation.
# 
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
# 
#           http://www.apache.org/licenses/LICENSE-2.0
# 
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

# Parameters
wasRootPath=$1                                      # Root path of WebSphere
wasProfileName=$2                                   # WAS profile name
wasServerName=$3                                    # WAS server name
dbType=$4                                           # Supported database types: db2
jdbcDataSourceName=$5                               # JDBC Datasource name
jdbcDSJNDIName=$(echo "${6}" | base64 -d)           # JDBC Datasource JNDI name
dsConnectionURL=$(echo "${7}" | base64 -d)          # JDBC Datasource connection String
databaseUser=$(echo "${8}" | base64 -d)             # Database username
databasePassword=$(echo "${9}" | base64 -d)         # Database user password

# Copy data source creation template per database type
createDsTemplate=create-ds-${dbType}.py.template
createDsScript=create-ds-${dbType}.py
cp $createDsTemplate $createDsScript

if [ $dbType == "db2" ]; then
    regex="^jdbc:db2://([^/]+):([0-9]+)/([[:alnum:]_-]+)"
    if [[ $dsConnectionURL =~ $regex ]]; then 
        db2ServerName="${BASH_REMATCH[1]}"
        db2ServerPortNumber="${BASH_REMATCH[2]}"
        db2DBName="${BASH_REMATCH[3]}"
    else
        echo "$dsConnectionURL doesn't match the required format of DB2 data source connection string."
        exit 1
    fi

    # Copy jdbc drivers
    jdbcDriverPath="$wasRootPath"/db2/java
    mkdir -p "$jdbcDriverPath"
    find "$wasRootPath" -name "db2jcc*.jar" | xargs -I{} cp {} "$jdbcDriverPath"
    jdbcDriverPath=$(realpath "$jdbcDriverPath")

    # Replace placeholder strings with user-input parameters
    sed -i "s/\${WAS_SERVER_NAME}/${wasServerName}/g" $createDsScript
    sed -i "s#\${DB2UNIVERSAL_JDBC_DRIVER_PATH}#${jdbcDriverPath}#g" $createDsScript
    sed -i "s/\${DB2_DATABASE_USER_NAME}/${databaseUser}/g" $createDsScript
    sed -i "s/\${DB2_DATABASE_USER_PASSWORD}/${databasePassword}/g" $createDsScript
    sed -i "s/\${DB2_DATABASE_NAME}/${db2DBName}/g" $createDsScript
    sed -i "s/\${DB2_DATASOURCE_NAME}/${jdbcDataSourceName}/g" $createDsScript
    sed -i "s#\${DB2_DATASOURCE_JNDI_NAME}#${jdbcDSJNDIName}#g" $createDsScript
    sed -i "s/\${DB2_SERVER_NAME}/${db2ServerName}/g" $createDsScript
    sed -i "s/\${PORT_NUMBER}/${db2ServerPortNumber}/g" $createDsScript
elif [ $dbType == "oracle" ]; then
    # Download jdbc drivers
    jdbcDriverPath="$wasRootPath"/oracle/java
    mkdir -p "$jdbcDriverPath"
    curl -Lo ${jdbcDriverPath}/ojdbc8.jar https://download.oracle.com/otn-pub/otn_software/jdbc/1916/ojdbc8.jar
    jdbcDriverClassPath=$(realpath "$jdbcDriverPath"/ojdbc8.jar)

    # Replace placeholder strings with user-input parameters
    sed -i "s/\${WAS_SERVER_NAME}/${wasServerName}/g" $createDsScript
    sed -i "s#\${ORACLE_JDBC_DRIVER_CLASS_PATH}#${jdbcDriverClassPath}#g" $createDsScript
    sed -i "s/\${ORACLE_DATABASE_USER_NAME}/${databaseUser}/g" $createDsScript
    sed -i "s/\${ORACLE_DATABASE_USER_PASSWORD}/${databasePassword}/g" $createDsScript
    sed -i "s/\${ORACLE_DATASOURCE_NAME}/${jdbcDataSourceName}/g" $createDsScript
    sed -i "s#\${ORACLE_DATASOURCE_JNDI_NAME}#${jdbcDSJNDIName}#g" $createDsScript
    sed -i "s#\${ORACLE_DATABASE_URL}#${dsConnectionURL}#g" $createDsScript
fi

# Create JDBC provider and data source using jython file
"$wasRootPath"/profiles/${wasProfileName}/bin/wsadmin.sh -lang jython -f $createDsScript

# Remove datasource creation script file
rm -rf $createDsScript
