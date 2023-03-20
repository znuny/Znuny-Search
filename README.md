# ElasticSearch

## Default endpoints on ports:
- instance: 9200,
-	nodes: 9300..,
- kibana: 5601.

## Set up environment
- Download ES 8.5+, Kibana 8.5+
- Go into directory

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

### Configuration(**config/elasticsearch.yml**)

#### *Specify cluster name*
*cluster.name* - Important setting which tells the nodes with the same cluster name to be linked together.

#### *SSL Enabled*

##### Go with the base instructions in this link: https://www.elastic.co/guide/en/elasticsearch/reference/current/security-basic-setup-https.html.

#### *SSL Disabled*

##### *Turn off need to enter kibana with login/passwd.*
*xpack.security.enabled*: true -> false

##### *Turn off need of enrollment.*
*xpack.security.enrollment.enabled*: true -> false

#### *Set master node.*
*cluster.initial_master_nodes*: [] -> ["ticket"]

#### *Add at least one node with "ingest" role so that attachment search by content will work.*
*node.roles*: [] -> ["master", "data", "ingest"]

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
      "routing":{ # optional
        "allocation":{
          "include":{
              "objectType" : "ticket"
          }
        }
      },
      "number_of_shards": 2,
    }
  }
}
```
With above request Elaticsearch engine will create "ticket" index.

If routing is enabled data will be allocated on nodes with objectType "ticket", with one primary shard/and one replica if there is a possibility to create replica (optional).

**number_of_shards** specifies how many shards the engine should create (split data between them).

## Usefull commands for debbuging allocation:

Retrieve information about actual health of cluster (important when operating on multiple shards).

`GET _cluster/health`

Retrieve information about size of index (sum of memory of all shard/nodes), specify health of each index (makes debugging easier).

`GET _cat/indices`

Retrieve information about each node (their shards (p - primary/r - replicas)) and many other important tabs.

`GET _cat/shards`

## GUI configuration

1. Go into new "Search Engine" Administrator view, then add new cluster.
2. Create new communication node with server properties. If SSL/HTTPS is enabled, select "Authentification" checkbox and fill in login and password. If connection test passed, save node.
3. (Optional) Select which indexes you want to include in your system. By default these are registered in system configuration option: "SearchEngine::Loader::Index*ActiveEngine*".
4. Go into reindexation view of the newly created cluster, select all indexes to reindex and execute this operation.
5. Live indexing works based on queue of data to index that is checked every minute by default. After this time it should be visible in the system.

## Settings

### System configuration

- "SearchEngine###Enabled", enable Search engines functionality,
- "SearchEngine::Loader::Engine", register Search engines,
- "SearchEngine::Loader::Index::ES", register indexes for Elasticsearch engine,
- "..EventModulePost..ObjectIndex", all event listeners for default indexes,
- "SearchEngine::Loader::Fields::Ticket", extension config to define new Fields into the index,
- "Daemon::SchedulerCronTaskManager::Task###SearchEngineReindex", cron task which re-indexes data at specified time when there is a mismatch between sql and elasticsearch object count,
- "Daemon::SchedulerCronTaskManager::Task###ES-IndexQueueDataProcess", cron task that checks (by default every 1 minute) cached queue of data to index,
- "SearchEngine::IndexationQueue###Settings", contains any settings for cached indexation queue,
- "SearchEngine::Reindexation###Settings", contains any settings for reindexation,
- "SearchEngine::Loader::Index::ES::Plugins###000-Framework", registers "Ingest" plugin for Elasticsearch,
- "SearchEngine::ES::TicketSearchFields###Fulltext", list of ticket properties that fulltext search will use. Ticket, article, attachment and dynamic fields columns can be used as a fields.

### Adding new index

#### Steps

1. Register new index in system configuration option: "SearchEngine::Loader::Index::*ActiveEngine*". Key represents index name that will be used by the API on the higher level of abstraction, value represents the raw index name.
2. If live-indexing is needed, add EventModulePost event listener similar to existing ones.
3. Create new modules:

    \- Kernel/System/Search/Object/Query/*IndexName*.pm

    \- Kernel/System/Search/Object/Default/*IndexName*.pm

As a pattern use e.g. the TicketHistory module.

#### Rules

1. Index will work only if there is a representation of its SQL table.
2. If first point is not met, custom support can be done using new module for functions, that is: Kernel/System/Search/Object/Engine/*ActiveEngine*/*IndexName*.pm

### CustomerUser configuration

Usage of CustomerUser backend can be set by changing configuration in
file "Kernel/Config/Defaults.pm":
- copy/override your configuration for DB backend,
that is $Self->{CustomerUser}, $Self->{CustomerUser1}, etc. in a way that it
will have higher priority,
- change inside new config ($Self->{CustomerUser}) "Name" to "Elasticsearch Backend" (optional),
- additionally change "Module" to "Kernel::System::CustomerUser::Elasticsearch",
- add "CustomerUserEmailTypeFields" as a list
of fields that are supposed to be an emails, example:
    ..
    CustomerUserEmailTypeFields => {
        'email' => 1,
    },
    ..

Elasticsearch should work for CustomerSearch in the system, if it's not enabled/connected
it will fallback to DB module.

Standard Search API (Kernel::System::Search->Search(..)) for CustomerUser will work regardless of this configuration.