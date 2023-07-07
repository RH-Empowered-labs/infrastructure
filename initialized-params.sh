#!/bin/bash

echo '      CONFIG - Initialized variables - folders';
dynamodbPath=dynamodb
parameterstorePath=parameterstore
secretsmanagerPath=secretsmanager

echo '      CONFIG - Initialized variables - paths';
# Rutas de los archivos de stacks
dynamodbTemplate=$dynamodbPath/movies-dynamodb-template.yaml
parameterstoreTemplate=$parameterstorePath/movies-parameterstore-template.yaml
secretsManagerTemplate=$secretsmanagerPath/movies-secretsmanager-template.yaml

echo '      AWS - Cloudformation create or verify stack - DynamoDB';

# Verificar si el stack de DynamoDB existe
if aws cloudformation describe-stacks --stack-name movies-dynamodb-stack >/dev/null 2>&1; then
    echo "Stack movies-dynamodb-stack already exists"
else
    echo "Stack movies-dynamodb-stack does not exist. Creating..."
    if aws cloudformation create-stack --stack-name movies-dynamodb-stack --template-body file://$dynamodbTemplate >/dev/null; then 
        aws cloudformation wait stack-create-complete --stack-name movies-dynamodb-stack
    else
        echo 'Error creating DynamoDB stack. Exiting.'
        exit 1
    fi
fi

# # Crear y esperar la finalización de la creación del stack de dynamo
echo '      AWS - Cloudformation create or verify stack - Secrets Manager';

# Verificar si el stack de Secrets Manager existe
if aws cloudformation describe-stacks --stack-name movies-secretsmanager-stack >/dev/null 2>&1; then
    echo "Stack movies-secretsmanager-stack already exists"
else
    echo "Stack movies-secretsmanager-stack does not exist. Creating..."
    if aws cloudformation create-stack --stack-name movies-secretsmanager-stack --template-body file://$secretsManagerTemplate >/dev/null; then
        aws cloudformation wait stack-create-complete --stack-name movies-secretsmanager-stack
    else
        echo 'Error creating Secrets Manager stack. Exiting.'
        exit 1
    fi
fi

# # Crear y esperar la finalización de la creación del stack de secretsmanager
echo '      AWS - Cloudformation Get outputs - DynamoDB';

# Obtiene los valores de salida del stack de DynamoDB
outputDynamoDb=$(aws cloudformation describe-stacks --stack-name movies-dynamodb-stack --query "Stacks[0].Outputs")

echo '      AWS - Cloudformation Get outputs - Secrets Manager';
# Obtiene los valores de salida del stack de SecretsManager
outputSecretsManager=$(aws cloudformation describe-stacks --stack-name movies-secretsmanager-stack --query "Stacks[0].Outputs")


echo '      JQ - Map outputs with specific variables - DynamoDB';
# Extrae los valores de MoviesTableArn y MoviesTableName del output de dynamodb
moviesTableArn=$(echo $outputDynamoDb | jq -r '.[] | select(.OutputKey=="MoviesTableArn") | .OutputValue')
moviesTableName=$(echo $outputDynamoDb | jq -r '.[] | select(.OutputKey=="MoviesTableName") | .OutputValue')

echo '      JQ - Map outputs with specific variables - Secrets Manager';
# Extrae los valores de JwtConfigurationSecretName y RemoteApiConfigurationSecretName del output de secrets manager
jwtConfigSecretARN=$(echo $outputSecretsManager | jq -r '.[] | select(.OutputKey=="JwtConfigurationSecretARN") | .OutputValue')
remoteApiConfigSecretARN=$(echo $outputSecretsManager | jq -r '.[] | select(.OutputKey=="RemoteApiConfigurationSecretARN") | .OutputValue')

echo '      AWS - Cloudformation create or verify stack - Parameter Store';

# Crea el stack de Parameter Store usando los valores de salida de los stacks de DynamoDB y Secret Manager 
if aws cloudformation describe-stacks --stack-name movies-parameterstore-stack >/dev/null 2>&1; then
    echo "Stack movies-parameterstore-stack already exists"
else
    echo "Stack movies-parameterstore-stack does not exist. Creating..."
    if aws cloudformation create-stack \
        --stack-name movies-parameterstore-stack \
        --template-body file://$parameterstoreTemplate \
        --parameters \
        ParameterKey=MoviesTableArn,ParameterValue=$moviesTableArn \
        ParameterKey=MoviesTableName,ParameterValue=$moviesTableName \
        ParameterKey=JwtConfigSecretName,ParameterValue=$jwtConfigSecretARN \
        ParameterKey=RemoteApiConfigSecretName,ParameterValue=$remoteApiConfigSecretARN \
        >/dev/null; then
        aws cloudformation wait stack-create-complete --stack-name movies-parameterstore-stack
    else
        echo 'Error creating Parameter Store stack. Exiting.'
        exit 1
    fi
fi
# Espera a que se cree el stack de Parameter Store
aws cloudformation wait stack-create-complete --stack-name movies-parameterstore-stack