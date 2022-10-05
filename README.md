# ElasticSearch

## Default endpoints on ports:
	instance: 9200,
	nodes: 9300..,
	kibana: 5601.

## Setup environment

- download ES 8, Kibana
- go into directory

### Create folders for storing data and logs(this step is optional, but recommended)
```
mkdir custom_data/ticket/data
mkdir custom_data/ticket/logs
```

### Enable more memory in options to be able to use more than single node locally
```
mkdir custom_data/ticket/data`
FILE="config/jvm.options.d/heap-size.options"
touch $FILE
echo -Xms2g>>$FILE
echo -Xmx2g>>$FILE
```

### Configuration(**config/elasticsearch.yml**)(Optional)

#### *Specify cluster name*
**cluster.name** - Important setting which tells our nodes with the same cluster name to be linked together.

#### *Turn off need to enter kibana with login/passwd.*
**xpack.security.enabled**: true -> false

#### *Turn off need of enrollment.*
**xpack.security.enrollment.enabled**: true -> false

#### *Set master node.*
**cluster.initial_master_nodes**: [] -> ["ticket"]


## How to run elasticsearch nodes

`./bin/elasticsearch -E node.name=ticket -E path.data=./custom_data/ticket/data -E path.logs=./custom_data/ticket/logs -E node.attr.objectType=ticket`

**node.name** - specifies node name of instance.

**path.data/path.logs** - Optional destination of data/logs.

**node.attr.objectType** (optional, use with care and knowledge) - way of distribute document into indexes with their objectType, this helps with creating structure that allocates data into nodes of specified type.

**There is possibility to use only one elasticsearch.yml per server**


## Initial setup of elastic search for ticket indexes

```
PUT ticket
{
  "settings": {
    "index":{
      "routing":{
        "allocation":{
          "include":{
              "objectType" : "ticket"
          }
        }
      }
    }
  }
}
```
With upper setting elatic will create ticket index that will allocate data on nodes with objectType "ticket", with one primary shard/and one replica if there is possibility to create replica

#### To extend index into another nodes there is possibility to tell index:

```
PUT ticket
{
  "settings": {
    "index":{
      "number_of_shards": 2,
      "routing":{
        "allocation":{
          "include":{
              "objectType" : "ticket"
          }
        }
      }
    }
  }
}

```
**number_of_shards** specifies how many shards engine should create(split data between nodes).


## Usefull commands for debbuging allocation:

Retrieve information about actual health of cluster(important when we're operating on multiple shards).

`GET _cluster/health`

Retrieve information about size of index(sum of memory of all shard/nodes), specify health of each index(make debug easier).

`GET _cat/indices`

Retrieve informations about each of node(their shards (p - primary/r - replicas)) and many other important tabs.

`GET _cat/shards`
