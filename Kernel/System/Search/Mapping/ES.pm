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

=head2 ResultFormat()

globally formats result of specified engine

    my $FormatResult = $SearchMappingESObject->ResultFormat(
        Result      => $ResponseResult,
        Config      => $Config,
        IndexName   => $IndexName,
    );

=cut

sub ResultFormat {
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

    my $GloballyFormattedObjData = $Self->ResponseDataFormat(
        Hits => $Result->{hits}->{hits},
        %Param,
    );

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

=head2 Search()

process query data to structure that will be used to execute query

    my $Result = $SearchMappingESObject->Search(
        QueryParams   => $QueryParams,
    );

=cut

sub Search {
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
            Field    => $Field,
            Value    => $Value,
            Operator => $Operator,
            Object   => $Param{Object},
        );

        my $Query = $Result->{Query};

        push @{ $Query{query}{bool}{ $Result->{Section} } }, $Query;
    }

    # filter only specified fields
    if ( IsArrayRefWithData( $Param{Fields} ) ) {
        for my $Field ( @{ $Param{Fields} } ) {
            push @{ $Query{fields} }, $Field->{ColumnName};
        }

        # data source won't be "_source" key anymore
        # instead it will be "fields"
        $Query{_source} = "false";
    }

    # TO-DO start sort:
    # datetimes won't work
    # for now text/integer type fields sorting works

    # set sorting field
    if ( $Param{SortBy} ) {

        # not specified
        my $OrderBy     = $Param{OrderBy} || "Up";
        my $OrderByStrg = $OrderBy eq 'Up' ? 'asc' : 'desc';

        if ( $Param{SortBy}->{Type} && $Param{SortBy}->{Type} eq 'Integer' ) {
            $Query{sort}->[0]->{ $Param{SortBy}->{ColumnName} } = {
                order => $OrderByStrg,
            };
        }
        else {
            $Query{sort}->[0]->{ $Param{SortBy}->{ColumnName} . ".keyword" } = {
                order => $OrderByStrg,
            };
        }
    }

    # TO-DO end: sort

    if ( $Param{Limit} ) {
        $Query{size} = $Param{Limit};
    }

    return \%Query;
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
    for my $Needed (qw(Config Index ObjectID Body)) {

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

        COLUMN:
        for my $Column (@ColumnsWithBlackListedType) {
            my $ColumnName = $IndexObject->{Fields}->{$Column}->{ColumnName};
            if ( $Param{Body}->{$ColumnName} && grep { $Param{Body}->{$ColumnName} eq $_ } @{$BlackListedValues} ) {
                $Param{Body}->{$ColumnName} = undef;
            }
        }
    }

    my $Result = {
        Index => $IndexObject->{Config}->{IndexRealName},
        Body  => $Param{Body}
    };

    return $Result;
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
    for my $Needed (qw(Config Index ObjectID Body)) {

        next NEEDED if defined $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    my $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::$Param{Index}");

    my $Result = {
        Index => $IndexObject->{Config}->{IndexRealName},
        Body  => $Param{Body}
    };

    return $Result;
}

=head2 ObjectIndexGet()

process query data to structure that will be used to execute query

=cut

sub ObjectIndexGet {
    my ( $Type, %Param ) = @_;

    return 1;
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
    my ( $Type, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(Config Index ObjectID)) {

        next NEEDED if defined $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    my $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::$Param{Index}");

    my $Result = {
        Index => $IndexObject->{Config}->{IndexRealName},
    };

    return $Result;    # Need to use perform_request()
}

=head2 ResponseDataFormat()

globally formats response data from engine

    my $Result = $SearchMappingESObject->ResponseDataFormat(
        Hits => $Hits,
        QueryData => $QueryData,
    );

=cut

sub ResponseDataFormat {
    my ( $Self, %Param ) = @_;

    return [] if !IsArrayRefWithData( $Param{Hits} );

    my $Hits = $Param{Hits};

    my @Objects;

    # when specified fields are filtered response
    # contains them inside "fields" key
    if ( $Param{QueryData}->{Query}->{_source} && $Param{QueryData}->{Query}->{_source} eq 'false' ) {
        for my $Hit ( @{$Hits} ) {
            my %Data;
            for my $Field ( sort keys %{ $Hit->{fields} } ) {
                $Data{$Field} = $Hit->{fields}->{$Field}->[0];
            }
            push @Objects, \%Data;
        }
    }

    # ES engine response stores objects inside "_source" key by default
    elsif ( IsHashRefWithData( $Hits->[0]->{_source} ) ) {
        for my $Hit ( @{$Hits} ) {
            push @Objects, $Hit->{_source};
        }
    }

    return \@Objects;
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

    my $Query = {
        Index => $IndexObject->{Config}->{IndexRealName},
        Body  => {
            query => {
                match_all => {}
            }
        }
    };

    return $Query;
}

=head2 DiagnosticFormat()

returns formatted response for diagnose of search engine

    my $Result = $SearchMappingESObject->DiagnosticFormat(
        Result => $Result
    );

=cut

sub DiagnosticFormat {
    my ( $Self, %Param ) = @_;

    my $DiagnosisResult = $Param{Result};
    my $ReceivedNodes   = $DiagnosisResult->{Nodes}->{nodes} || {};
    my $ReceivedIndexes = $DiagnosisResult->{Indexes} || [];

    my %Nodes;
    for my $Node ( sort keys %{$ReceivedNodes} ) {
        $Node = $ReceivedNodes->{$Node};
        $Nodes{ $Node->{name} } = {
            TransportAddress => $Node->{transport_address},
            Shards           => $Node->{indices}->{shard_stats}->{total_count},
            ObjectType       => $Node->{attributes}->{objectType},
            Name             => $Node->{attributes}->{objectType},
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

    my $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::$Param{Index}");

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

    my $Fields = $IndexObject->{Fields};

    my %Body;
    for my $FieldName ( sort keys %{$Fields} ) {
        $Body{ $Fields->{$FieldName}->{ColumnName} } = $DataTypes->{ $Fields->{$FieldName}->{Type} };
    }

    my $Query = {
        Index => $IndexObject->{Config}->{IndexRealName},
        Body  => {
            properties => {
                %Body
            }
        }
    };

    return $Query;
}

=head2 IndexMappingResultFormat()

format mapping result from engine

    my $Result = $SearchMappingESObject->IndexMappingResultFormat(
        Result => $Result,
    );

=cut

sub IndexMappingResultFormat {
    my ( $Self, %Param ) = @_;

    my $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::$Param{Index}");
    my $LogObject   = $Kernel::OM->Get('Kernel::System::Log');

    my $Properties = $Param{Result}->{ $IndexObject->{Config}->{IndexRealName} }->{mappings}->{properties} || {};

    my $FieldsMapping = {
        date    => "Date",
        text    => "String",
        integer => "Integer",
        long    => "Long"
    };

    my %FormattedResult;
    ATTRIBUTE:
    for my $Attribute ( sort keys %{$Properties} ) {
        my @ColumnName
            = grep { $IndexObject->{Fields}->{$_}->{ColumnName} eq $Attribute } keys %{ $IndexObject->{Fields} };
        my $FieldConfig = $IndexObject->{Fields}->{ $ColumnName[0] };
        my $FieldType   = $FieldsMapping->{ $Properties->{$Attribute}->{type} } || '';

        $FieldConfig->{Type} = $FieldType;
        $FormattedResult{ $ColumnName[0] } = $FieldConfig;
    }

    return \%FormattedResult;
}

1;
