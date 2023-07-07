#!/bin/bash

echo '      CONFIG - Initialized variables - folders';
s3Path=s3
lambdasPath=lambdas
dynamodbPath=dynamodb
apiGetwayPath=apigetway
parameterstorePath=parameterstore
secretsmanagerPath=secretsmanager

echo '      CONFIG - Initialized variables - paths';
# Rutas de los archivos de stacks
s3Template=$s3Path/movies-s3-template.yaml
lambdasTemplate=$lambdasPath/movies-lambdas-template.yaml
dynamodbTemplate=$dynamodbPath/movies-dynamodb-template.yaml
apiGetwayTemplate=$apiGetwayPath/movies-apigetway-template.yaml
parameterstoreTemplate=$parameterstorePath/movies-parameterstore-template.yaml
secretsManagerTemplate=$secretsmanagerPath/movies-secretsmanager-template.yaml

echo '      AWS - Cloudformation create or verify stack - s3';

# Verificar si el stack de s3 existe
if aws cloudformation describe-stacks --stack-name movies-s3-stack >/dev/null 2>&1; then
    echo "Stack movies-s3-stack already exists"
else
    echo "Stack movies-s3-stack does not exist. Creating..."
    if aws cloudformation create-stack --stack-name movies-s3-stack --template-body file://$s3Template >/dev/null; then 
        aws cloudformation wait stack-create-complete --stack-name movies-s3-stack
    else
        echo 'Error creating s3 stack. Exiting.'
        exit 1
    fi
fi


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

# # Crear y esperar la finalización de la creación del stack de lambdas
echo '      AWS - Cloudformation create or verify stack - Lambdas';

# Verificar si el stack de Lambdas existe
if aws cloudformation describe-stacks --stack-name movies-lambdas-stack >/dev/null 2>&1; then
    echo "Stack movies-lambdas-stack already exists"
else
    echo "Stack movies-lambdas-stack does not exist. Creating..."
    if aws cloudformation create-stack --stack-name movies-lambdas-stack --template-body file://$lambdasTemplate --capabilities CAPABILITY_IAM >/dev/null; then
        aws cloudformation wait stack-create-complete --stack-name movies-lambdas-stack
    else
        echo 'Error creating Lambdas stack. Exiting.'
        exit 1
    fi
fi

echo '      AWS - Cloudformation Get outputs - Lambdas';
# Obtiene los valores de salida del stack de DynamoDB
outputLambdas=$(aws cloudformation describe-stacks --stack-name movies-lambdas-stack --query "Stacks[0].Outputs")

echo '      AWS - Cloudformation Get outputs - DynamoDB';
# Obtiene los valores de salida del stack de DynamoDB
outputDynamoDb=$(aws cloudformation describe-stacks --stack-name movies-dynamodb-stack --query "Stacks[0].Outputs")


echo '      AWS - Cloudformation Get outputs - Secrets Manager';
# Obtiene los valores de salida del stack de SecretsManager
outputSecretsManager=$(aws cloudformation describe-stacks --stack-name movies-secretsmanager-stack --query "Stacks[0].Outputs")


echo '      JQ - Map outputs with specific variables - Lambdas';
# Extrae los valores de MoviesTableArn y MoviesTableName del output de dynamodb
lambdaMoviesArn=$(echo $outputLambdas | jq -r '.[] | select(.OutputKey=="MoviesLambdaFunctionArn") | .OutputValue')
lambdaUsersArn=$(echo $outputLambdas | jq -r '.[] | select(.OutputKey=="UsersLambdaFunctionArn") | .OutputValue')

echo '      JQ - Map outputs with specific variables - DynamoDB';
# Extrae los valores de MoviesTableArn y MoviesTableName del output de dynamodb
moviesTableArn=$(echo $outputDynamoDb | jq -r '.[] | select(.OutputKey=="MoviesTableArn") | .OutputValue')
moviesTableName=$(echo $outputDynamoDb | jq -r '.[] | select(.OutputKey=="MoviesTableName") | .OutputValue')

echo '      JQ - Map outputs with specific variables - Secrets Manager';
# Extrae los valores de JwtConfigurationSecretName y RemoteApiConfigurationSecretName del output de secrets manager
jwtConfigSecretARN=$(echo $outputSecretsManager | jq -r '.[] | select(.OutputKey=="JwtConfigurationSecretARN") | .OutputValue')
remoteApiConfigSecretARN=$(echo $outputSecretsManager | jq -r '.[] | select(.OutputKey=="RemoteApiConfigurationSecretARN") | .OutputValue')

echo '      AWS - Cloudformation create or verify stack - Parameter Store';

# Crea el stack de Api Getway usando los valores de salida del Stack de Lambdas 
if aws cloudformation describe-stacks --stack-name movies-apiGetway-stack >/dev/null 2>&1; then
    echo "Stack movies-apiGetway-stack already exists"
else
    echo "Stack movies-apiGetway-stack does not exist. Creating..."
    if aws cloudformation create-stack \
        --stack-name movies-apiGetway-stack \
        --template-body file://$apiGetwayTemplate \
        --parameters \
        ParameterKey=MoviesLambdaFunction,ParameterValue=$lambdaMoviesArn \
        ParameterKey=UsersLambdaFunction,ParameterValue=$lambdaUsersArn \
        >/dev/null; then
        aws cloudformation wait stack-create-complete --stack-name movies-apiGetway-stack
    else
        echo 'Error creating Parameter Store stack. Exiting.'
        exit 1
    fi
fi
# Espera a que se cree el stack de Parameter Store
aws cloudformation wait stack-create-complete --stack-name movies-apiGetway-stack


echo '      AWS - Cloudformation Get outputs - APIGetway';
# Obtiene los valores de salida del stack de DynamoDB
outputAPIGetway=$(aws cloudformation describe-stacks --stack-name movies-apiGetway-stack --query "Stacks[0].Outputs")

echo '      JQ - Map outputs with specific variables - APIGetway';
# Extrae los valores de JwtConfigurationSecretName y RemoteApiConfigurationSecretName del output de secrets manager
moviesApiGetwayArn=$(echo $outputAPIGetway | jq -r '.[] | select(.OutputKey=="MoviesApiGetwayArn") | .OutputValue')

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
        ParameterKey=MoviesLambdaFunctionArn,ParameterValue=$lambdaMoviesArn \
        ParameterKey=UsersLambdaFunctionArn,ParameterValue=$lambdaUsersArn \
        ParameterKey=ApiGatewayArn,ParameterValue=$moviesApiGetwayArn \
        >/dev/null; then
        aws cloudformation wait stack-create-complete --stack-name movies-parameterstore-stack
    else
        echo 'Error creating Parameter Store stack. Exiting.'
        exit 1
    fi
fi
# Espera a que se cree el stack de Parameter Store
aws cloudformation wait stack-create-complete --stack-name movies-parameterstore-stack