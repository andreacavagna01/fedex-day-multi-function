import json
import requests

def lambda_handler(event, context):
    headers = {
        'X-Vault-Token': 's.wS59C22PZF83UMD1pukYWJ4m',
    }

    response = requests.get('http://34.245.5.31:8200/v1/cubbyhole/besharp', headers=headers)
    print(response.json())
    # TODO implement
    return {
        'statusCode': 200,
        'body': response.json()
    }




