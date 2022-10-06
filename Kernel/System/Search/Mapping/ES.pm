# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
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
        FieldsDefinition => $Param{FieldsDefinition},
        QueryParams      => $Param{QueryParams},
        Object           => $Param{Object},
    );

    my $QueryPath = "$Param{RealIndexName}/";

    if ( $Param{ResultType} && $Param{ResultType} eq 'COUNT' ) {
        $QueryPath .= '_count';
    }
    else {
        # data source won't be "_source" key anymore
        # instead it will be "fields"
        $Body{_source} = "false";
        $QueryPath .= '_search';
        @{ $Body{fields} } = @{ $Param{Fields} };

        # TO-DO start sort:
        # datetimes won't work
        # for now text/integer type fields sorting works

        # set sorting field
        if ( $Param{SortBy} ) {

            # not specified
            my $OrderBy     = $Param{OrderBy} || "Up";
            my $OrderByStrg = $OrderBy eq 'Up' ? 'asc' : 'desc';

            if ( $Param{SortBy}->{Type} && $Param{SortBy}->{Type} eq 'Integer' ) {
                $Body{sort}->[0]->{ $Param{SortBy}->{ColumnName} } = {
                    order => $OrderByStrg,
                };
            }
            else {
                $Body{sort}->[0]->{ $Param{SortBy}->{ColumnName} . ".keyword" } = {
                    order => $OrderByStrg,
                };
            }
        }

        if ( $Param{Limit} ) {
            $Body{size} = $Param{Limit};
        }

        # TO-DO end: sort
    }

    my $Query = {
        Body   => \%Body,
        Method => 'GET',
        Path   => $QueryPath,
    };

    return $Query;
}

=head2 SearchFormat()

globally formats search result of specified engine

    my $FormatResult = $SearchMappingESObject->SearchFormat(
        Result      => $ResponseResult,
        Config      => $Config,
        IndexName   => $IndexName,
    );

=cut

sub SearchFormat {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(Result Config IndexName)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Missing param: $Needed",
        );
        return;
    }

    my $IndexName = $Param{IndexName};
    my $Result    = $Param{Result};

    return {
        Reason => $Result->{reason},
        Status => $Result->{status},
        Type   => $Result->{type}
    } if $Result->{status};

    my $GloballyFormattedObjData;
    if ( $Param{ResultType} ne 'COUNT' ) {

        $GloballyFormattedObjData = $Self->_ResponseDataFormat(
            Hits => $Result->{hits}->{hits},
            %Param,
        );
    }
    else {
        $GloballyFormattedObjData = $Result->{count};
    }

    return {
        "$IndexName" => {
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

    my $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::$Param{Index}");

    # workaround for elastic search date validation
    my @DataTypesWithBlackList = keys %{ $IndexObject->{DataTypeValuesBlackList} };

    for my $DataTypeWithBlackList (@DataTypesWithBlackList) {

        my $BlackListedValues = $IndexObject->{DataTypeValuesBlackList}->{$DataTypeWithBlackList};
        my @ColumnsWithBlackListedType
            = grep { $IndexObject->{Fields}->{$_}->{Type} eq $DataTypeWithBlackList } keys %{ $IndexObject->{Fields} };
        for my $Object ( @{ $Param{Body} } ) {
            COLUMN:
            for my $Column (@ColumnsWithBlackListedType) {
                my $ColumnName = $IndexObject->{Fields}->{$Column}->{ColumnName};
                if ( $Object->{$ColumnName} && grep { $Object->{$ColumnName} eq $_ } @{$BlackListedValues} ) {
                    $Object->{$ColumnName} = undef;
                }
            }
        }
    }

    my $IndexConfig = $IndexObject->{Config};

    my $BodyForBulkRequest;
    for my $Object ( @{ $Param{Body} } ) {
        my $IdentifierRealName = $IndexObject->{Fields}->{ $IndexConfig->{Identifier} }->{ColumnName};

        push @{$BodyForBulkRequest},
            {
            id     => $Object->{$IdentifierRealName},
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

    my $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::$Param{Index}");

    my $IndexConfig = $IndexObject->{Config};

    my $BodyForBulkRequest;
    for my $Object ( @{ $Param{Body} } ) {
        my $IdentifierRealName = $IndexObject->{Fields}->{ $IndexConfig->{Identifier} }->{ColumnName};

        push @{$BodyForBulkRequest},
            {
            id  => $Object->{$IdentifierRealName},
            doc => {
                %{$Object}
            }
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
        FieldsDefinition => $FieldsDefinition,
    );

=cut

sub ObjectIndexRemove {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    if ( !$Param{FieldsDefinition} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Need FieldsDefinition!"
        );
    }

    my $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::$Param{Index}");

    my $Refresh = {};

    if ( $Param{Refresh} ) {
        $Refresh = {
            refresh => 'true',
        };
    }

    if ( $Param{ObjectID} ) {
        if ( ref( $Param{ObjectID} ) eq 'ARRAY' ) {
            return {
                Path   => "/$IndexObject->{Config}->{IndexRealName}/_delete_by_query",
                QS     => $Refresh,
                Method => 'POST',
                Body   => {
                    query => {
                        bool => {
                            must => [
                                {
                                    terms => {
                                        id => $Param{ObjectID},
                                    }
                                }
                            ]
                        }
                    }
                }
            };
        }
        else {
            return {
                Path   => "/$IndexObject->{Config}->{IndexRealName}/_doc/$Param{ObjectID}",
                QS     => $Refresh,
                Method => 'DELETE',
            };
        }
    }
    elsif ( $Param{QueryParams} ) {
        my %QueryBody = $Self->_BuildQueryBodyFromParams(
            QueryParams      => $Param{QueryParams},
            FieldsDefinition => $Param{FieldsDefinition},
            Object           => $Param{Index},
        );

        return {
            Path   => "/$IndexObject->{Config}->{IndexRealName}/_delete_by_query",
            QS     => $Refresh,
            Method => 'POST',
            Body   => \%QueryBody,
        };
    }
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

    my %Settings = IsHashRefWithData( $Param{Settings} ) ? %{ $Param{Settings} } : $Self->DefaultRemoteSettingsGet(
        RoutingAllocation => $Param{SetRoutingAllocation} ? $Param{IndexRealName} : undef,
    );

    my $Query = {
        Path => $Param{IndexRealName},
        Body => \%Settings
    };

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

    my $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::$Param{Index}");

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
                match_all => {}
            }
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

    my $Fields      = $Param{Fields};
    my $IndexConfig = $Param{IndexConfig};

    my %Body;

    if ( $Param{SetAliases} ) {
        for my $FieldName ( sort keys %{$Fields} ) {
            $Body{$FieldName} = {
                type => 'alias',
                path => $Fields->{$FieldName}->{ColumnName},
            };
        }
    }

    my $DataTypes = {
        Date => {
            type   => "date",
            format => "YYYY-MM-dd HH:mm:ss",
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
                    type => "keyword",
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
        }
    };

    for my $FieldName ( sort keys %{$Fields} ) {
        $Body{ $Fields->{$FieldName}->{ColumnName} } = $DataTypes->{ $Fields->{$FieldName}->{Type} };
    }

    my $Query = {
        Index => $IndexConfig->{IndexRealName},
        Body  => {
            properties => {
                %Body
            }
        }
    };

    return $Query;
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
        Index => $Param{Index}
    );

    if ( IsHashRefWithData($ActualIndexMapping) ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "There is already existing mapping for index: '$Param{Index}'. " .
                "Depending on the engine, the index may need to be reinitialized on the engine side.",
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

    my $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::$Param{Index}");
    my $Response    = $Param{Response};
    my $Properties  = $Response->{ $IndexObject->{Config}->{IndexRealName} }->{mappings}->{properties} || {};

    # check if raw engine response is needed
    if ( !$Param{Format} ) {

        # filter out aliases if not specified to get
        if ( !$Param{GetAliases} ) {
            if ( IsHashRefWithData($Properties) ) {
                for my $MappingProperty ( sort keys %{$Properties} ) {
                    if ( $Properties->{$MappingProperty}->{type} && $Properties->{$MappingProperty}->{type} eq 'alias' )
                    {
                        delete $Response->{ $IndexObject->{Config}->{IndexRealName} }->{mappings}->{properties}
                            ->{$MappingProperty};
                    }
                }
            }
        }
        return $Response;
    }

    my $FieldsMapping = {
        date    => "Date",
        text    => "String",
        integer => "Integer",
        long    => "Long"
    };

    # prepare formatted result
    my $FormattedResult;
    ATTRIBUTE:
    for my $Attribute ( sort keys %{$Properties} ) {

        my $IsAliasConfig = $IndexObject->{Fields}->{$Attribute};

        if ( $Param{GetAliases} && $IsAliasConfig ) {
            if ( $Properties->{$Attribute}->{path} && $Properties->{$Attribute}->{type} ) {
                my $Path = $Properties->{$Attribute}->{path};
                my $Type = $Properties->{$Attribute}->{type};

                $FormattedResult->{Aliases}->{$Attribute} = {
                    Path => $Path,
                    Type => $Type,
                };
            }
        }
        elsif ( !$IsAliasConfig ) {
            my @ColumnName
                = grep { $IndexObject->{Fields}->{$_}->{ColumnName} eq $Attribute } keys %{ $IndexObject->{Fields} };

            my $FieldConfig = $IndexObject->{Fields}->{ $ColumnName[0] };
            my $FieldType   = $FieldsMapping->{ $Properties->{$Attribute}->{type} } || '';

            $FieldConfig->{Type} = $FieldType;
            $FormattedResult->{Mapping}->{ $ColumnName[0] } = $FieldConfig;
        }
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
                max_result_window => 2000000,
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

=head2  _ResponseDataFormat()

globally formats response data from engine

    my $Result = $SearchMappingESObject->_ResponseDataFormat(
        Hits => $Hits,
        QueryData => $QueryData,
    );

=cut

sub _ResponseDataFormat {
    my ( $Self, %Param ) = @_;

    return [] if !IsArrayRefWithData( $Param{Hits} );

    my $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::$Param{IndexName}");

    my $Hits = $Param{Hits};

    my @Objects;

    my $FieldsDefinition = $IndexObject->{Fields};
    my @Fields           = keys %{$FieldsDefinition};

    # when specified fields are filtered response
    # contains them inside "fields" key
    if ( $Param{QueryData}->{Query}->{Body}->{_source} && $Param{QueryData}->{Query}->{Body}->{_source} eq 'false' ) {
        for my $Hit ( @{$Hits} ) {
            my %Data;
            for my $Field (@Fields) {
                $Data{$Field} = $Hit->{fields}->{$Field}->[0];
            }
            push @Objects, \%Data;
        }
    }

    # ES engine response stores objects inside "_source" key by default
    # IMPORTANT: not used anymore!
    elsif ( IsHashRefWithData( $Hits->[0]->{_source} ) ) {
        for my $Hit ( @{$Hits} ) {
            push @Objects, $Hit->{_source};
        }
    }

    return \@Objects;
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
    my @BlackListedValues = ( 'uuid', 'creation_date', 'version', 'provided_name' );

    my $IndexSettings = {};
    if ( $Response->{ $SearchObject->{Config}->{RegisteredIndexes}->{ $Param{Index} } } ) {
        $IndexSettings = $Response->{ $SearchObject->{Config}->{RegisteredIndexes}->{ $Param{Index} } };
        for my $BlackListedValue (@BlackListedValues) {
            delete $IndexSettings->{settings}->{index}->{$BlackListedValue};
        }
    }

    return $IndexSettings;
}

=head2 _BuildQueryBodyFromParams()

build query form params

    my %Query = $SearchMappingESObject->_BuildQueryBodyFromParams(
        QueryParams     => $QueryParams,
        FieldDefinition => $FieldDefinition,
        Object          => $Object,
    );

=cut

sub _BuildQueryBodyFromParams {
    my ( $Self, %Param ) = @_;

    my %Query = ();

    # build query from parameters
    PARAM:
    for my $Field ( sort keys %{ $Param{QueryParams} } ) {

        my $Value;
        my $Operator;

        if ( ref $Param{QueryParams}->{$Field} eq "HASH" ) {
            $Operator = $Param{QueryParams}->{$Field}->{Operator} || "=";
            $Value    = $Param{QueryParams}->{$Field}->{Value} // "";
        }
        else {
            $Operator = "=";
            $Value    = $Param{QueryParams}->{$Field} // '';
        }

        next PARAM if !$Field;

        my $OperatorModule = $Kernel::OM->Get("Kernel::System::Search::Object::Operators");

        my $Result = $OperatorModule->OperatorQueryGet(
            Field    => $Param{FieldsDefinition}->{$Field}->{ColumnName},
            Value    => $Value,
            Operator => $Operator,
            Object   => $Param{Object},
        );

        my $Query = $Result->{Query};

        push @{ $Query{query}{bool}{ $Result->{Section} } }, $Query;
    }

    return %Query;
}

1;
