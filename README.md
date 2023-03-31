Znuny-Search
====================

Znuny-Search provides a new API for search within the Znuny framework.
It includes "only" the API for the new search. No other functionality
is linked to it.

We can be sure that there is no interference with older APIs/modules, as we've built it from scratch.
If you find bugs, please report them here in the repository.

Please note that we do not provide a manual on how to set up [Elasticsearch](https://www.elastic.co/guide/en/elasticsearch/reference/current/install-elasticsearch.html), nor do we give resource recommendations on set-up

The above guide from the developers of Elasticsearch is good indeed.

Requirements
============
- Znuny 6.5+
- Search::Elasticsearch (CPAN)
- Elasticsearch 7+

- [Znuny-SearchAPI](https://github.com/znuny/Znuny-SearchFrontend/) *optional* as there is no current front-end implementation, you will need this if you are not developing your own add-on.

Functionality
=============

This package provides a new search API, which makes use of index search engines like Elasticsearch.

The following objects are currently available:

* Tickets
* Ticket History
* Article
* Article Data Mime
* Dynamic Fields
* Dynamic Field Values
* Customer User

Other objects will follow over time. Developers can also add their own objects. For example, it is possible to include your tables to be indexed by the search API.

Future Features
=============

We already know that we want to add more features over the time.
Some of them are:
- Add other index engines
- Add Grafana samples

Vendor
=======
This project is part of the Znuny project.
[Znuny on GitHub](https://github.com/znuny/Znuny/)

If you need professional support or consulting, feel free to contact us.

[Znuny Website](https://www.znuny.com)
