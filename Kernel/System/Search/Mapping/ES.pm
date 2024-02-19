# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Mapping::ES;

use strict;
use warnings;

use parent qw( Kernel::System::Search::Mapping );

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Search::Object::Operators',
    'Kernel::System::Search',
);

=head1 NAME

Kernel::System::Search::Mapping::ES - elastic search mapping lib

=head1 DESCRIPTION

Functions to map parameters from/to query/response to API functions.

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $SearchMappingESObject = $Kernel::OM->Get('Kernel::System::Search::Mapping::ES');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=head2 Search()

process query data to structure that will be used to execute query

    my $Result = $SearchMappingESObject->Search(
        QueryParams   => $QueryParams,
    );

=cut

sub Search {
    my ( $Self, %Param ) = @_;

    my %Body = $Self->_BuildQueryBodyFromParams(
        QueryParams => $Param{QueryParams},
        Object      => $Param{Object},
    );

    my $QueryPath = "$Param{RealIndexName}/";

    if ( !$Param{ResultType} || $Param{ResultType} ne 'COUNT' ) {

        # set sorting field
        if ( $Param{SortBy} ) {

            my $SortByQuery = $Self->SortByQueryBuild(
                SortBy => {
                    %{ $Param{SortBy} },
                },
            );

            $Body{sort} = $SortByQuery->{Query} if ( IsHashRefWithData($SortByQuery) );
        }

        if ( $Param{Limit} ) {
            $Body{size} = $Param{Limit};
        }

        $QueryPath .= '_search';

        # get original indexed lucene document from source or
        # via fields - ES specific responses
        if ( $Param{_Source} ) {
            if ( !keys %{ $Param{Fields} } ) {

                # push empty source
                # in this way elasticsearch
                # will return no fields at all
                push @{ $Body{_source} }, "";
            }
            else {
                @{ $Body{_source} } = keys %{ $Param{Fields} };
            }
        }
        else {
            $Body{_source} = "false";
            @{ $Body{fields} } = keys %{ $Param{Fields} };
        }
    }
    else {
        $QueryPath .= '_count';
    }

    my $Query = {
        Body   => \%Body,
        Method => 'GET',
        Path   => $QueryPath,
    };

    return $Query;
}

=head2 AdvancedSearch()

process advanced query data to structure that will be used to execute query

    my $Result = $SearchMappingESObject->AdvancedSearch(
        QueryParams         => $QueryParams,
        AdvancedQueryParams => $AdvancedQueryParams,
    );

=cut

sub AdvancedSearch {
    my ( $Self, %Param ) = @_;

    my $SearchIndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::Default::$Param{Object}");
    my $SQLQuery          = $SearchIndexObject->SQLObjectSearch(
        QueryParams         => $Param{QueryParams},
        AdvancedQueryParams => $Param{AdvancedQueryParams},
        SelectAliases       => 1,
        OnlyReturnQuery     => 1,
        %Param,
    );

    return if !$SQLQuery->{Success};

    if ( IsArrayRefWithData( $SQLQuery->{Bind} ) ) {

        # de-reference bind values for ES engine
        for my $Bind ( @{ $SQLQuery->{Bind} } ) {
            $Bind = ${$Bind};
        }
    }

    return {
        Method => 'POST',
        Path   => '_sql',
        Body   => {
            query  => "$SQLQuery->{SQL}",
            params => $SQLQuery->{Bind},
        }
    };
}

=head2 SearchFormat()

globally formats search result of specified engine

    my $FormatResult = $SearchMappingESObject->SearchFormat(
        Result      => $ResponseResult,
        IndexName   => $IndexName,
    );

=cut

sub SearchFormat {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(IndexName)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Missing param: $Needed",
        );
        return;
    }

    my $IndexName = $Param{IndexName};
    my $Result    = $Param{Result};

    if ( $Result->{status} ) {
        return {
            Reason => $Result->{reason},
            Status => $Result->{status},
            Type   => $Result->{type},
        };
    }

    my $GloballyFormattedObjData;

    # identify format of response
    if ( $Param{ResultType} ne 'COUNT' ) {
        $GloballyFormattedObjData = $Self->_ResponseDataFormat(
            Result => $Result,
            %Param,
        );
    }
    else {
        if ( $Result->{columns} ) {
            $GloballyFormattedObjData = $Result->{rows}->[0]->[0];
        }
        else {
            $GloballyFormattedObjData = $Result->{count};
        }
    }

    return {
        $IndexName => {
            ObjectData => $GloballyFormattedObjData,
            EngineData => {
                Shards       => $Result->{_shards},
                ResponseTime => $Result->{took},
            }
        }
    };
}

=head2 ObjectIndexAdd()

process query data to structure that will be used to execute query

    my $Result = $SearchMappingESObject->ObjectIndexAdd(
        Config   => $Config,
        Index    => $Index,
        ObjectID => $ObjectID,
        Body     => $Body,
    );

=cut

sub ObjectIndexAdd {
    my ( $Type, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(Config Index Body)) {
        next NEEDED if defined $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    my $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::Default::$Param{Index}");
    my $IndexConfig = $IndexObject->{Config};

    my $BodyForBulkRequest;
    for my $Object ( @{ $Param{Body} } ) {
        push @{$BodyForBulkRequest},
            {
            id     => delete $Object->{_ID} || $Object->{ $IndexConfig->{Identifier} },
            source => $Object
            };
    }

    my $Refresh = {};

    if ( $Param{Refresh} ) {
        $Refresh = {
            refresh => 'true',
        };
    }

    my $Result = {
        Index   => $IndexObject->{Config}->{IndexRealName},
        Body    => $BodyForBulkRequest,
        Refresh => $Refresh,
    };

    return $Result;
}

=head2 ObjectIndexAddFormat()

format response from elastic search

    my $FormattedResponse = $SearchMappingESObject->ObjectIndexAddFormat(
        Response => $Response,
    );

=cut

sub ObjectIndexAddFormat {
    my ( $Self, %Param ) = @_;

    return $Self->ResponseIsSuccess(
        Response => $Param{Response},
    );
}

=head2 ObjectIndexSet()

process query data to structure that will be used to execute query

    my $Result = $SearchMappingESObject->ObjectIndexSet(
        Config   => $Config,
        Index    => $Index,
        Body     => $Body,
    );

=cut

sub ObjectIndexSet {
    my ( $Type, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(Config Index Body)) {
        next NEEDED if defined $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    my $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::Default::$Param{Index}");
    my $IndexConfig = $IndexObject->{Config};

    my $BodyForBulkRequest;
    for my $Object ( @{ $Param{Body} } ) {

        push @{$BodyForBulkRequest},
            {
            id     => delete $Object->{_ID} || $Object->{ $IndexConfig->{Identifier} },
            source => $Object
            };
    }

    my $Refresh = {};

    if ( $Param{Refresh} ) {
        $Refresh = {
            refresh => 'true',
        };
    }

    my $Result = {
        Index   => $IndexObject->{Config}->{IndexRealName},
        Body    => $BodyForBulkRequest,
        Refresh => $Refresh,
    };

    return $Result;
}

=head2 ObjectIndexSetFormat()

format response from elastic search

    my $FormattedResponse = $SearchMappingESObject->ObjectIndexSetFormat(
        Response => $Response,
    );

=cut

sub ObjectIndexSetFormat {
    my ( $Self, %Param ) = @_;

    return $Self->ResponseIsSuccess(
        Response => $Param{Response},
    );
}

=head2 ObjectIndexUpdate()

process query data to structure that will be used to execute query

    my $Result = $SearchMappingESObject->ObjectIndexUpdate(
        Config   => $Config,
        Index    => $Index,
        ObjectID => $ObjectID,
        Body     => $Body,
    );

=cut

sub ObjectIndexUpdate {
    my ( $Type, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(Config Index Body)) {
        next NEEDED if defined $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    my $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::Default::$Param{Index}");

    my $IndexConfig = $IndexObject->{Config};

    my $BodyForBulkRequest;
    for my $Object ( @{ $Param{Body} } ) {
        push @{$BodyForBulkRequest},
            {
            id  => $Object->{ $IndexConfig->{Identifier} },
            doc => {
                %{$Object},
            },
            };
    }

    my $Refresh = {};

    if ( $Param{Refresh} ) {
        $Refresh = {
            refresh => 'true',
        };
    }

    my $Result = {
        Index   => $IndexObject->{Config}->{IndexRealName},
        Body    => $BodyForBulkRequest,
        Refresh => $Refresh,
    };

    return $Result;
}

=head2 ObjectIndexUpdateFormat()

format response from elastic search

    my $Success = $SearchMappingESObject->ObjectIndexUpdateFormat(
        Response => $Response,
    );

=cut

sub ObjectIndexUpdateFormat {
    my ( $Self, %Param ) = @_;

    return $Self->ResponseIsSuccess(
        Response => $Param{Response},
    );
}

=head2 ObjectIndexRemove()

process query data to structure that will be used to execute query

    my $Result = $SearchMappingESObject->ObjectIndexRemove(
        Config   => $Config,
        Index    => $Index,
        ObjectID => $ObjectID,
    );

=cut

sub ObjectIndexRemove {
    my ( $Self, %Param ) = @_;

    my $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::Default::$Param{Index}");

    my $Refresh = {};

    if ( $Param{Refresh} ) {
        $Refresh = {
            refresh => 'true',
        };
    }

    if ( $Param{QueryParams} ) {
        my %QueryBody = $Self->_BuildQueryBodyFromParams(
            QueryParams => $Param{QueryParams},
            Object      => $Param{Index},
        );

        return {
            Path   => "/$IndexObject->{Config}->{IndexRealName}/_delete_by_query",
            QS     => $Refresh,
            Method => 'POST',
            Body   => \%QueryBody,
        };
    }
    return;
}

=head2 ObjectIndexRemoveFormat()

format response from elastic search

    my $Success = $SearchMappingESObject->ObjectIndexRemoveFormat(
        Response => $Response,
    );

=cut

sub ObjectIndexRemoveFormat {
    my ( $Self, %Param ) = @_;

    return $Self->ResponseIsSuccess(
        Response => $Param{Response},
    );
}

=head2 IndexAdd()

returns query for engine to add specified index

    my $Result = $SearchMappingESObject->IndexAdd(
        IndexRealName => 'ticket',
    );

=cut

sub IndexAdd {
    my ( $Self, %Param ) = @_;

    my $LogObject   = $Kernel::OM->Get('Kernel::System::Log');
    my $IndexConfig = $Param{IndexConfig};

    NEEDED:
    for my $Needed (qw(Fields IndexConfig)) {

        next NEEDED if defined $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    my %Settings = IsHashRefWithData( $Param{Settings} ) ? %{ $Param{Settings} } : $Self->DefaultRemoteSettingsGet(
        RoutingAllocation => $Param{SetRoutingAllocation} ? $Param{IndexRealName} : undef,
    );

    my $Query = {
        Path => $Param{IndexRealName},
        Body => \%Settings
    };

    # create email uax url analyzer for index
    my $CreateEmailUaxURLAnalyzer;
    FIELD:
    for my $Field ( sort keys %{ $Param{Fields} } ) {
        if ( $Param{Fields}->{$Field}->{Type} eq 'Email' ) {
            $CreateEmailUaxURLAnalyzer = 1;
            last FIELD;
        }
    }

    if ($CreateEmailUaxURLAnalyzer) {
        $Query->{Body}->{settings}->{analysis}->{analyzer}->
            {email_uax_url_analyzer}->{tokenizer} = 'email_uax_url_tokenizer';
        $Query->{Body}->{settings}->{analysis}->{tokenizer}->
            {email_uax_url_tokenizer}->{type} = 'uax_url_email';
    }

    return $Query;
}

=head2 IndexAddFormat()

format response from elastic search

    my $Success = $SearchMappingESObject->IndexAddFormat(
        Response => $Response,
    );

=cut

sub IndexAddFormat {
    my ( $Self, %Param ) = @_;

    return $Self->ResponseIsSuccess(
        Response => $Param{Response},
    );
}

=head2 IndexRemove()

returns query for engine to remove specified index

    my $Result = $SearchMappingESObject->IndexRemove(
        IndexRealName => 'ticket',
    );

=cut

sub IndexRemove {
    my ( $Self, %Param ) = @_;

    my $Query = {
        Index => $Param{IndexRealName},
    };

    return $Query;
}

=head2 IndexRemoveFormat()

format response from elastic search

    my $Success = $SearchMappingESObject->IndexRemoveFormat(
        Response => $Response,
    );

=cut

sub IndexRemoveFormat {
    my ( $Self, %Param ) = @_;

    return $Self->ResponseIsSuccess(
        Response => $Param{Response},
    );
}

=head2 IndexList()

returns query for engine to list all indexes

    my $Result = $SearchMappingESObject->IndexList();

=cut

sub IndexList {
    my ( $Self, %Param ) = @_;

    my $Query = {
        Path   => '_cat/indices',
        Format => 'JSON',
    };

    return $Query;
}

=head2 IndexListFormat()

returns formatted response for index list in search engine

    my @IndexList = $SearchMappingESObject->IndexListFormat(
        Response => $Response,
    );

=cut

sub IndexListFormat {
    my ( $Self, %Param ) = @_;

    return () if !$Self->ResponseIsSuccess(
        Response => $Param{Response},
    );

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    for my $Name (qw(Config)) {
        if ( !$Param{$Name} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Name!"
            );
            return ();
        }
    }

    my @Response = @{ $Param{Result} };

    my @FormattedData;

    # note: can add diagnostic properties param get here
    for my $IndexData (@Response) {
        if ( $IndexData->{index} ) {
            push @FormattedData, $IndexData->{index};
        }
    }

    return @FormattedData;
}

=head2 IndexClear()

returns query for engine to clear whole index from objects

    my $Result = $SearchMappingESObject->IndexClear(
        Index => $Index,
    );

=cut

sub IndexClear {
    my ( $Self, %Param ) = @_;

    my $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::Default::$Param{Index}");

    my $Refresh = {};

    if ( $Param{Refresh} ) {
        $Refresh = {
            refresh => 'true',
        };
    }

    my $Query = {
        Index => $IndexObject->{Config}->{IndexRealName},
        Body  => {
            query => {
                match_all => {},
            },
        },
        Refresh => $Refresh,
    };

    return $Query;
}

=head2 IndexClearFormat()

format response from elastic search

    my $Success = $SearchMappingESObject->IndexClearFormat(
        Response => $Response,
    );

=cut

sub IndexClearFormat {
    my ( $Self, %Param ) = @_;

    return $Self->ResponseIsSuccess(
        Response => $Param{Response},
    );
}

=head2 DiagnosticDataGet()

returns query for engine to clear whole index from objects

    my $Result = $SearchMappingESObject->DiagnosticDataGet(
        Index => $Index,
    );

=cut

sub DiagnosticDataGet {
    my ( $Self, %Param ) = @_;

    my $Query = {
        Cluster => {
            Path => '_cluster/health',
        },
        Nodes => {
            Path => '_nodes/stats',
        },
        Indexes => {
            Path => '_cat/indices',
        },
    };

    return $Query;
}

=head2 DiagnosticDataGetFormat()

returns formatted response for diagnose of search engine

    my $DiagnosticData = $SearchMappingESObject->DiagnosticDataGetFormat(
        Response => $Response
    );

=cut

sub DiagnosticDataGetFormat {
    my ( $Self, %Param ) = @_;

    my $DiagnosisResult = $Param{Response};
    my $ReceivedNodes   = $DiagnosisResult->{Nodes}->{nodes} || {};
    my $ReceivedIndexes = $DiagnosisResult->{Indexes} || [];

    my %Nodes;
    for my $Node ( sort keys %{$ReceivedNodes} ) {
        $Node = $ReceivedNodes->{$Node};
        $Nodes{ $Node->{name} } = {
            TransportAddress => $Node->{transport_address},
            Shards           => $Node->{indices}->{shard_stats}->{total_count},
            IP               => $Node->{ip}
        };
    }

    my %Indexes;
    for my $Index ( @{$ReceivedIndexes} ) {
        my @IndexAttributes = split( ' ', $Index );
        $Indexes{ $IndexAttributes[2] } = {
            Status         => $IndexAttributes[0],
            Size           => $IndexAttributes[8],
            PrimaryShards  => $IndexAttributes[4],
            RecoveryShards => $IndexAttributes[5],
        };
    }

    my $Diagnosis = {
        Cluster => {
            ClusterName                 => $DiagnosisResult->{Cluster}->{cluster_name},
            Status                      => $DiagnosisResult->{Cluster}->{status},
            TimedOut                    => $DiagnosisResult->{Cluster}->{timed_out},
            NumberOfNodes               => $DiagnosisResult->{Cluster}->{number_of_nodes},
            NumberOfDataNodes           => $DiagnosisResult->{Cluster}->{number_of_data_nodes},
            NumberOfPrimaryShards       => $DiagnosisResult->{Cluster}->{active_primary_shards},
            ActiveShards                => $DiagnosisResult->{Cluster}->{active_shards},
            RelocatingShards            => $DiagnosisResult->{Cluster}->{relocating_shards},
            InitializingShards          => $DiagnosisResult->{Cluster}->{initializing_shards},
            UnassignedShards            => $DiagnosisResult->{Cluster}->{unassigned_shards},
            DelayedUnassignedShards     => $DiagnosisResult->{Cluster}->{delayed_unassigned_shards},
            NumberOfPendingTasks        => $DiagnosisResult->{Cluster}->{number_of_pending_tasks},
            NumberOfInFlightFetch       => $DiagnosisResult->{Cluster}->{number_of_in_flight_fetch},
            TaskMaxWaitingInQueueMillis => $DiagnosisResult->{Cluster}->{task_max_waiting_in_queue_millis},
            ActiveShardsPercentAsNumber => $DiagnosisResult->{Cluster}->{active_shards_percent_as_number},
        },
        Nodes => {
            %Nodes,
        },
        Indexes => {
            %Indexes,
        }
    };

    return $Diagnosis;
}

=head2 IndexMappingSet()

returns query for engine mapping data types

    my $Result = $SearchMappingESObject->IndexMappingSet(
        Index => $Index,
    );

=cut

sub IndexMappingSet {
    my ( $Self, %Param ) = @_;

    my %Body;
    my $Fields         = $Param{Fields};
    my $ExternalFields = $Param{ExternalFields};
    my $IndexConfig    = $Param{IndexConfig};

    my $DataTypes = $Self->MappingDataTypesGet();

    FIELD:
    for my $FieldName ( sort keys %{$Fields} ) {
        next FIELD if $ExternalFields->{$FieldName};
        my $FieldType = $Fields->{$FieldName}->{Type};
        $Body{$FieldName} = $DataTypes->{$FieldType};

        if ( $Fields->{$FieldName}->{Alias} ) {
            $Body{ $Fields->{$FieldName}->{ColumnName} } = {
                type => 'alias',
                path => $FieldName,
            };
            if ( $FieldType =~ 'Long|String|Integer|Date|Email' ) {

                # dot is not supported as body name for alias
                # keyword mapping - use instead "_" character
                $Body{ $Fields->{$FieldName}->{ColumnName} . '_keyword' } = {
                    type => 'alias',
                    path => $FieldName . '.keyword',
                };
            }
        }
    }

    # set custom aliases & mapping for external fields
    EXTERNAL_FIELD:
    for my $FieldName ( sort keys %{$ExternalFields} ) {
        next EXTERNAL_FIELD if $Fields->{$FieldName};

        if ( $ExternalFields->{$FieldName}->{Alias} ) {
            $Body{$FieldName} = {
                type => 'alias',
                path => $ExternalFields->{$FieldName}->{ColumnName},
            };

            $Body{ $ExternalFields->{$FieldName}->{ColumnName} }
                = $DataTypes->{ $ExternalFields->{$FieldName}->{Type} };

        }
        else {
            $Body{$FieldName} = $DataTypes->{ $ExternalFields->{$FieldName}->{Type} };
        }
    }

    my $Query = {
        Index => $IndexConfig->{IndexRealName},
        Body  => {
            properties => {
                %Body,
            },
        },
    };

    return $Query;
}

=head2 IndexBaseInit()

returns query for engine mapping data types

    my $Result = $SearchMappingESObject->IndexBaseInit(
        Index => $Index,
    );

=cut

sub IndexBaseInit {
    my ( $Self, %Param ) = @_;

    return;
}

=head2 IndexBaseInitFormat()

format response from Elasticsearch engine

    my $Result = $SearchMappingESObject->IndexBaseInitFormat(
        Index => $Index,
    );

=cut

sub IndexBaseInitFormat {
    my ( $Self, %Param ) = @_;

    my $Success = $Self->ResponseIsSuccess(
        Response => $Param{Response},
    );

    return 1 if $Success;
    return;
}

=head2 MappingDataTypesGet()

get data types mapping

    my $Result = $SearchMappingESObject->MappingDataTypesGet();

=cut

sub MappingDataTypesGet {
    my ( $Self, %Param ) = @_;

    return {
        Date => {
            type   => "date",
            format => "yyyy-MM-dd HH:mm:ss",
            fields => {
                keyword => {
                    type         => "keyword",
                    ignore_above => 20,
                }
            }
        },
        Integer => {
            type   => "integer",
            fields => {
                keyword => {
                    type => "keyword",
                }
            }
        },
        String => {
            type   => "text",
            fields => {
                keyword => {
                    type         => "keyword",
                    ignore_above => 8191
                }
            }
        },
        Long => {
            type   => "long",
            fields => {
                keyword => {
                    type => "keyword",
                }
            }
        },
        Textarea => {
            type => "text",
        },
        Blob => {
            type => "binary",
        },
        Email => {
            type   => "text",
            fields => {
                keyword => {
                    type => "keyword",
                },
                email_uax_url_analyzer => {
                    type     => 'text',
                    analyzer => 'email_uax_url_analyzer',
                }
            }
        }
    };
}

=head2 IndexMappingSetFormat()

format response from elastic search

    my $Success = $SearchMappingESObject->IndexMappingSetFormat(
        Response => $Response,
    );

=cut

sub IndexMappingSetFormat {
    my ( $Self, %Param ) = @_;

    my $Success = $Self->ResponseIsSuccess(
        Response => $Param{Response},
    );

    return 1 if $Success;

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');
    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');

    # if there was any problems on index mapping set, then check mapping
    my $ActualIndexMapping = $SearchObject->IndexMappingGet(
        Index => $Param{Index},
    );

    if ( IsHashRefWithData($ActualIndexMapping) ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "There is already an existing mapping for index '$Param{Index}'. " .
                "Depending on the search engine, the index may need to be re-initialized on the search engine side.",
        );
    }

    return;
}

=head2 IndexMappingGet()

returns query for engine mapping data types

    my $Result = $SearchMappingESObject->IndexMappingGet(
        Index => $Index,
    );

=cut

sub IndexMappingGet {
    my ( $Self, %Param ) = @_;

    return {
        Path => "$Param{IndexRealName}/_mapping",
    };
}

=head2 IndexMappingGetFormat()

format mapping result from engine

    my $IndexMapping = $SearchMappingESObject->IndexMappingGetFormat(
        Response => $Response,
    );

=cut

sub IndexMappingGetFormat {
    my ( $Self, %Param ) = @_;

    my $Success = $Self->ResponseIsSuccess(
        Response => $Param{Response},
    );

    return if !$Success;

    my $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::Default::$Param{Index}");
    my $Response    = $Param{Response};
    my $Properties  = $Response->{ $IndexObject->{Config}->{IndexRealName} }->{mappings}->{properties} || {};

    # check if raw engine response is needed
    return $Response if !$Param{Format};

    my $FieldsMapping = {
        date    => "Date",
        text    => "String",
        integer => "Integer",
        long    => "Long",
    };

    # prepare formatted result
    my $FormattedResult;

    ATTRIBUTE:
    for my $Attribute ( sort keys %{$Properties} ) {
        my $ColumnName = $Attribute;

        my $FieldConfig = $IndexObject->{Fields}->{$ColumnName};
        my $FieldType   = $FieldsMapping->{ $Properties->{$Attribute}->{type} } || '';

        $FieldConfig->{Type} = $FieldType;
        $FormattedResult->{Mapping}->{$ColumnName} = $FieldConfig;
    }

    return $FormattedResult;
}

=head2 DefaultRemoteSettingsGet()

get default remote settings

    my %DefaultRemoteSettings = $Object->DefaultRemoteSettingsGet();

=cut

sub DefaultRemoteSettingsGet {
    my ( $Self, %Param ) = @_;

    my %Result = (
        settings => {
            index => {
                number_of_shards  => 6,
                max_result_window => 50000,
            }
        }
    );

    return %Result;
}

=head2 ResponseIsSuccess()

default success format response from elastic search

    my $ResponseIsSuccess = $SearchMappingESObject->ResponseIsSuccess( %Param );

=cut

sub ResponseIsSuccess {
    my ( $Self, %Param ) = @_;

    return $Param{Response}->{__Error} ? undef : 1;
}

=head2 IndexInitialSettingsGet()

create query for index initial setting receive

    my $Result = $SearchQueryObject->IndexInitialSettingsGet(
        IndexRealName => 'ticket',
        FieldDefinition => $FieldDefinition,
        Object          => $Object,
    );

=cut

sub IndexInitialSettingsGet {
    my ( $Self, %Param ) = @_;

    my $Query = {
        Path => $Param{IndexRealName} . '/_settings',
    };

    return $Query;
}

=head2 IndexInitialSettingsGetFormat()

format response of initial settings get to ready to go form

    my $Result = $SearchQueryObject->IndexInitialSettingsGetFormat(
        Response => $Response,
    );

=cut

sub IndexInitialSettingsGetFormat {
    my ( $Self, %Param ) = @_;

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');

    return {} if !$Param{Response};

    my $Response = $Param{Response};

    # Attributes which needs to be removed from response.
    my @BlackListedValues = qw( uuid creation_date version provided_name );

    my $IndexSettings = {};
    if ( $Response->{ $SearchObject->{Config}->{RegisteredIndexes}->{ $Param{Index} } } ) {
        $IndexSettings = $Response->{ $SearchObject->{Config}->{RegisteredIndexes}->{ $Param{Index} } };
        for my $BlackListedValue (@BlackListedValues) {
            delete $IndexSettings->{settings}->{index}->{$BlackListedValue};
        }
    }

    return $IndexSettings;
}

=head2 IndexRefresh()

refresh index data on engine side

    my $Result = $SearchMappingESObject->IndexRefresh(
        IndexRealName => $IndexRealName,
    );

=cut

sub IndexRefresh {
    my ( $Self, %Param ) = @_;

    return {
        Path   => $Param{IndexRealName} . '/_refresh',
        Method => 'POST',
    };
}

=head2 QueryFieldNameBuild()

build sort by field name

    my $FieldName = $SearchMappingESObject->QueryFieldNameBuild(
        Type => $Param{SortBy}->{Properties}->{Type},
        Name => $Param{SortBy}->{Name},
    );

=cut

sub QueryFieldNameBuild {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(Type Name)) {

        next NEEDED if defined $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    # _id is reserved in elastic search as identifier of documents
    # this can't get keyword if we want to search by it
    if ( $Param{Name} eq '_id' ) {
        return $Param{Name};
    }

    # any email field will need to use email analyzer
    # it is needed so that elasticsearch will not separate
    # an email into couple of words
    if ( $Param{Type} eq 'Email' ) {
        return $Param{Name} . '.email_uax_url_analyzer';
    }
    if ( $Param{Type} ne 'Integer' && $Param{Type} ne 'Date' ) {
        return $Param{Name} . '.keyword';
    }

    return $Param{Name};
}

=head2 SortByQueryBuild()

build sort by query part

    my $SortByField = $SearchMappingESObject->SortByQueryBuild(
        SortBy =>
        {
            Properties => {
                Type => 'String',
            }
            Name => 'TicketID',
            OrderBy => 'Up',
        }
    );

=cut

sub SortByQueryBuild {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    if ( !IsHashRefWithData( $Param{SortBy} ) ) {

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter 'SortBy' is needed!",
        );
        return;
    }

    my $SortByFieldName = $Self->QueryFieldNameBuild(
        Type    => $Param{SortBy}->{Properties}->{Type},
        Name    => $Param{SortBy}->{Name},
        OrderBy => $Param{SortBy}->{OrderBy},
    );

    return if ( !$SortByFieldName && $Param{Strict} );

    my %OrderByMap = (
        'Up'   => 'asc',
        'Down' => 'desc',
    );

    my $OrderBy = $Param{SortBy}->{OrderBy} || 'Up';
    my $Query   = {
        $SortByFieldName => {
            order => $OrderByMap{$OrderBy} || 'asc',
        }
    };

    return {
        Query   => $Query,
        Success => 1,
    };
}

=head2 LimitQueryBuild()

build query limit

    my $LimitQuery = $SearchMappingESObject->LimitQueryBuild(
        Limit => 1000,
    );

=cut

sub LimitQueryBuild {
    my ( $Self, %Param ) = @_;

    if ( IsPositiveInteger( $Param{Limit} ) ) {
        return {
            Query => {
                size => $Param{Limit},
            },
            Success => 1,
        };
    }
    else {
        return if !$Param{IndexName};
        my $QueryObject  = $Kernel::OM->Get("Kernel::System::Search::Object::Query::$Param{IndexName}");
        my $DefaultLimit = $QueryObject->{IndexDefaultSearchLimit};
        return if !IsPositiveInteger($DefaultLimit);
        return {
            Query => {
                size => $DefaultLimit,
            },
            Success => 2,
        };
    }
}

=head2 FulltextSearchableFieldBuild()

build specified field is searchable in fulltext context

    my $Result = $SearchMappingESObject->FulltextSearchableFieldBuild(
        Field => 'TicketNumber',
        Index => 'Ticket',
        Entity => 'Ticket',
    );

=cut

sub FulltextSearchableFieldBuild {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(Field Index Entity)) {

        next NEEDED if defined $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    my $SearchIndexObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::Ticket');
    my $MappingDataTypes  = $Self->MappingDataTypesGet();
    my $Index             = $Param{Index};
    my $Field             = $Param{Field};
    my $Entity            = $Param{Entity};

    my %Field = $SearchIndexObject->ValidFieldsPrepare(
        Fields      => ["${Entity}_${Field}"],
        Object      => $Index,
        QueryParams => {},
    );

    my $Type            = $Field{$Entity}->{$Field}->{Type};
    my $MappingDataType = $MappingDataTypes->{$Type}->{type};

    if ( $MappingDataType && $MappingDataType eq 'text' ) {
        return $Field;
    }
    elsif ( $MappingDataTypes->{$Type}->{fields}->{keyword} ) {
        return $Field . '.keyword';
    }
    elsif ( !$Param{Silent} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "$Entity property '$Field' is not valid for a fulltext search!",
        );
    }
    return;
}

=head2 _ResponseDataFormat()

globally formats response data from engine

    my $Result = $SearchMappingESObject->_ResponseDataFormat(
        Result => $Result,
        QueryData => $QueryData,
    );

=cut

sub _ResponseDataFormat {
    my ( $Self, %Param ) = @_;

    my $Objects;
    my $SimpleArray = $Param{ResultType} && $Param{ResultType} eq 'ARRAY_SIMPLE' ? 1 : 0;
    my $SimpleHash  = $Param{ResultType} && $Param{ResultType} eq 'HASH_SIMPLE'  ? 1 : 0;

    if ( IsArrayRefWithData( $Param{Result}->{hits}->{hits} ) ) {
        my $Hits   = $Param{Result}->{hits}->{hits};
        my @Fields = keys %{ $Param{Fields} };

        # when specified fields are filtered response
        # contains them inside "fields" key
        if (
            $Param{QueryData}->{Query}->{Body}->{_source}
            && $Param{QueryData}->{Query}->{Body}->{_source} eq 'false'
            )
        {
            # filter scalar/array fields by return type
            my @ScalarFields;
            my @ArrayFields;

            # decide if simple format is needed
            # othwersie it will be an array of objects
            if ($SimpleArray) {
                for my $Hit ( @{$Hits} ) {
                    for my $Field ( sort keys %{ $Hit->{fields} } ) {
                        push @{$Objects}, $Hit->{fields}->{$Field}->[0];
                    }
                }
                return $Objects;
            }
            elsif ($SimpleHash) {
                for my $Hit ( @{$Hits} ) {
                    for my $Field ( sort keys %{ $Hit->{fields} } ) {
                        $Objects->{ $Hit->{fields}->{$Field}->[0] } = 1;
                    }
                }
                return $Objects;
            }
            else {
                @ScalarFields = grep { $Param{Fields}->{$_}->{ReturnType} !~ m{\AARRAY|HASH\z} } @Fields;
                @ArrayFields  = grep { $Param{Fields}->{$_}->{ReturnType} eq 'ARRAY' } @Fields;
            }

            for my $Hit ( @{$Hits} ) {
                my %Data;

                # get proper data for scalar/hash/arrays from response
                for my $Field (@ScalarFields) {
                    $Data{$Field} = $Hit->{fields}->{$Field}->[0];
                }

                for my $Field (@ArrayFields) {
                    $Data{$Field} = $Hit->{fields}->{$Field};
                }

                push @{$Objects}, \%Data;
            }
        }

        # ES engine response stores objects inside "_source" key by default
        elsif ( IsHashRefWithData( $Hits->[0]->{_source} ) ) {
            if ($SimpleArray) {
                for my $Hit ( @{$Hits} ) {
                    if ( IsHashRefWithData( $Hit->{_source} ) ) {
                        for my $Value ( values %{ $Hit->{_source} } ) {
                            push @{$Objects}, $Value;
                        }
                    }
                }
            }
            elsif ($SimpleHash) {
                for my $Hit ( @{$Hits} ) {
                    if ( IsHashRefWithData( $Hit->{_source} ) ) {
                        for my $Value ( values %{ $Hit->{_source} } ) {
                            $Objects->{$Value} = 1;
                        }
                    }
                }
                return $Objects;
            }
            else {
                if ( $Param{QueryData}->{RetrieveHighlightData} ) {
                    for my $Hit ( @{$Hits} ) {
                        my $Data = $Hit->{_source};

                        if ( $Hit->{highlight} ) {
                            $Data->{_Highlight} = $Hit->{highlight};
                        }
                        push @{$Objects}, $Data;
                    }
                }
                else {
                    for my $Hit ( @{$Hits} ) {
                        push @{$Objects}, $Hit->{_source};
                    }
                }
            }
        }
    }
    elsif ( IsArrayRefWithData( $Param{Result}->{rows} ) ) {
        for ( my $j = 0; $j < scalar @{ $Param{Result}->{rows} }; $j++ ) {
            my %Data;
            for ( my $i = 0; $i < scalar @{ $Param{Result}->{columns} }; $i++ ) {
                $Data{ $Param{Result}->{columns}->[$i]->{name} } = $Param{Result}->{rows}->[$j]->[$i];
            }
            push @{$Objects}, \%Data;
        }
    }

    return $Objects;
}

=head2 _BuildQueryBodyFromParams()

build query from params

    my %Query = $SearchMappingESObject->_BuildQueryBodyFromParams(
        QueryParams     => $QueryParams,
        Object          => $Object,
    );

=cut

sub _BuildQueryBodyFromParams {
    my ( $Self, %Param ) = @_;

    my %Query        = ();
    my $SearchParams = $Param{QueryParams};

    # build query from parameters
    for my $FieldName ( sort keys %{$SearchParams} ) {
        for my $OperatorData ( @{ $SearchParams->{$FieldName}->{Query} } ) {
            my $OperatorValue  = $OperatorData->{Value};
            my $OperatorModule = $Kernel::OM->Get("Kernel::System::Search::Object::Operators");

            my $Result = $OperatorModule->OperatorQueryGet(
                Field      => $FieldName,
                ReturnType => $OperatorData->{ReturnType},
                Value      => $OperatorValue,
                Operator   => $OperatorData->{Operator},
                FieldType  => $OperatorData->{Type},
                Object     => $Param{Object},
            );

            my $Query = $Result->{Query};

            push @{ $Query{query}->{bool}->{ $Result->{Section} } }, $Query;
        }
    }

    return %Query;
}

=head2 _AppendQueryBodyFromParams()

append to query from params

    my $Success = $SearchMappingESObject->_AppendQueryBodyFromParams(
        QueryParams     => $QueryParams,
        Query           => $Query,
    );

=cut

sub _AppendQueryBodyFromParams {
    my ( $Self, %Param ) = @_;

    return if !$Param{Query};

    my $SearchParams = $Param{QueryParams};
    my $Success      = 1;

    # build query from parameters
    for my $FieldName ( sort keys %{$SearchParams} ) {
        for my $OperatorData ( @{ $SearchParams->{$FieldName}->{Query} } ) {
            my $OperatorValue  = $OperatorData->{Value};
            my $OperatorModule = $Kernel::OM->Get("Kernel::System::Search::Object::Operators");

            my $Result = $OperatorModule->OperatorQueryGet(
                Field      => $FieldName,
                ReturnType => $OperatorData->{ReturnType},
                Value      => $OperatorValue,
                Operator   => $OperatorData->{Operator},
                FieldType  => $OperatorData->{Type},
                Object     => $Param{Object},
            );

            my $Query = $Result->{Query};

            push @{ $Param{Query}->{Body}->{query}->{bool}->{ $Result->{Section} } }, $Query;
            $Success = $Query ? 1 : 0 if $Success;
        }
    }

    return $Success;
}

1;
