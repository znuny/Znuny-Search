# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Base;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsHashRefWithData IsArrayRefWithData);

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::DB',
    'Kernel::Config',
    'Kernel::System::Search::Object::Operators',
    'Kernel::System::Search::Object',
    'Kernel::System::Search',
);

=head1 NAME

Kernel::System::Search::Object::Base - common base backend functions

=head1 DESCRIPTION

Proceed with fallback, format operation response, load custom columns and
other base related functions.

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $SearchBaseObject = $Kernel::OM->Get('Kernel::System::Search::Object::Base');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    $LogObject->Log(
        Priority => 'error',
        Message  => "Constructor needs to be overridden!",
    );

    return $Self;
}

=head2 Fallback()

Fallback from using advanced search for specific index.

Should return same response as advanced search
engine globally formatted response.

    my $Result = $SearchBaseObject->Fallback(
        QueryParams  => {
            TicketID => 1,
        },
        Limit        => $Limit,
        OrderBy      => $OrderBy,
        SortBy       => $SortBy,
        ResultType   => $ResultType,
        Fields       => $Fields,
    );

=cut

sub Fallback {
    my ( $Self, %Param ) = @_;

    my $DBObject  = $Kernel::OM->Get('Kernel::System::DB');
    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    my $SQLSearchResult = {
        Success => 0,
        Data    => [],
    };

    if ( IsHashRefWithData( $Param{Fields} ) ) {
        $SQLSearchResult = $Self->SQLObjectSearch(
            QueryParams                 => $Param{QueryParams},
            AdvancedQueryParams         => $Param{AdvancedQueryParams},
            Limit                       => $Param{Limit} || $Self->{DefaultSearchLimit},
            OrderBy                     => $Param{OrderBy},
            SortBy                      => $Param{SortBy},
            ResultType                  => $Param{ResultType},
            Fields                      => $Param{Fields},
            Silent                      => $Param{Silent},
            ReturnDefaultSQLColumnNames => 0,
        );

        return if !$SQLSearchResult->{Success};
    }

    my $Result = {
        EngineData => {},
        ObjectData => $SQLSearchResult->{Data},
    };

    return $Result;
}

=head2 ObjectIndexAdd()

add object for specified index

    my $Success = $SearchObject->ObjectIndexAdd(
        Index    => 'Ticket',
        Refresh  => 1, # optional, define if indexed data needs
                       # to be refreshed for search call
                       # not refreshed data could not be found right after
                       # indexing (for example in elastic search engine)

        ObjectID => 1, # possible:
                       # - for single object indexing: 1
                       # - for multiple object indexing: [1,2,3]
        # or
        QueryParams => {
            TicketID => [1,2,3],
            SLAID => {
                Operator => 'IS NOT EMPTY'
            },
        },
    );

=cut

sub ObjectIndexAdd {
    my ( $Self, %Param ) = @_;

    my $SearchChildObject = $Kernel::OM->Get('Kernel::System::Search::Object');

    my $PreparedQuery = $SearchChildObject->QueryPrepare(
        %Param,
        Operation     => 'ObjectIndexAdd',
        Config        => $Param{Config},
        MappingObject => $Param{MappingObject},
    );

    return 0 if !$PreparedQuery;

    my $Response = $Param{EngineObject}->QueryExecute(
        %Param,
        Operation     => 'ObjectIndexAdd',
        Query         => $PreparedQuery,
        ConnectObject => $Param{ConnectObject},
        Config        => $Param{Config},
    );

    return $Param{MappingObject}->ObjectIndexAddFormat(
        %Param,
        Response => $Response,
        Config   => $Param{Config},
    );
}

=head2 ObjectIndexSet()

set (update if exists or create if not exists) object for specified index

    my $Success = $SearchObject->ObjectIndexSet(
        Index    => "Ticket",
        Refresh  => 1, # optional, define if indexed data needs
                       # to be refreshed for search call
                       # not refreshed data could not be found right after
                       # indexing (for example in elastic search engine)

        ObjectID => 1, # possible:
                       # - for single object indexing: 1
                       # - for multiple object indexing: [1,2,3]
        # or
        QueryParams => {
            TicketID => [1,2,3],
            SLAID => {
                Operator => 'IS NOT EMPTY'
            },
        },
    );

=cut

sub ObjectIndexSet {
    my ( $Self, %Param ) = @_;

    my $SearchChildObject = $Kernel::OM->Get('Kernel::System::Search::Object');

    my $PreparedQuery = $SearchChildObject->QueryPrepare(
        %Param,
        Operation     => "ObjectIndexSet",
        Config        => $Param{Config},
        MappingObject => $Param{MappingObject},
    );

    return 0 if !$PreparedQuery;

    my $Response = $Param{EngineObject}->QueryExecute(
        %Param,
        Operation     => "ObjectIndexSet",
        Query         => $PreparedQuery,
        ConnectObject => $Param{ConnectObject},
        Config        => $Param{Config},
    );

    return $Param{MappingObject}->ObjectIndexSetFormat(
        %Param,
        Response => $Response,
        Config   => $Param{Config},
    );
}

=head2 ObjectIndexUpdate()

update object for specified index

    my $Success = $SearchObject->ObjectIndexUpdate(
        Index => "Ticket",
        Refresh  => 1, # optional, define if indexed data needs
                       # to be refreshed for search call
                       # not refreshed data could not be found right after
                       # indexing (for example in elastic search engine)

        ObjectID => 1, # possible:
                       # - for single object indexing: 1
                       # - for multiple object indexing: [1,2,3]
        # or
        QueryParams => {
            TicketID => [1,2,3],
            SLAID => {
                Operator => 'IS NOT EMPTY'
            },
        },
    );

=cut

sub ObjectIndexUpdate {
    my ( $Self, %Param ) = @_;

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search::Object');

    my $PreparedQuery = $SearchObject->QueryPrepare(
        %Param,
        Operation     => "ObjectIndexUpdate",
        Config        => $Param{Config},
        MappingObject => $Param{MappingObject},
    );

    return 0 if !$PreparedQuery;

    my $Response = $Param{EngineObject}->QueryExecute(
        %Param,
        Query         => $PreparedQuery,
        Operation     => "ObjectIndexUpdate",
        ConnectObject => $Param{ConnectObject},
        Config        => $Param{Config},
    );

    return $Param{MappingObject}->ObjectIndexUpdateFormat(
        %Param,
        Response => $Response,
        Config   => $Param{Config},
    );
}

=head2 ObjectIndexRemove()

remove object for specified index

    my $Success = $SearchObject->ObjectIndexRemove(
        Index => "Ticket",
        Refresh  => 1, # optional, define if indexed data needs
                       # to be refreshed for search call
                       # not refreshed data could not be found right after
                       # indexing (for example in elastic search engine)

        ObjectID => 1, # possible:
                       # - for single object indexing: 1
                       # - for multiple object indexing: [1,2,3]
        # or
        QueryParams => {
            TicketID => [1,2,3],
            SLAID => {
                Operator => 'IS NOT EMPTY'
            },
        },
    );

=cut

sub ObjectIndexRemove {
    my ( $Self, %Param ) = @_;

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search::Object');

    my $PreparedQuery = $SearchObject->QueryPrepare(
        %Param,
        Operation     => "ObjectIndexRemove",
        Config        => $Param{Config},
        MappingObject => $Param{MappingObject},
    );

    return 0 if !$PreparedQuery;

    my $Response = $Param{EngineObject}->QueryExecute(
        %Param,
        Query         => $PreparedQuery,
        Operation     => "ObjectIndexRemove",
        ConnectObject => $Param{ConnectObject},
        Config        => $Param{Config},
    );

    return $Param{MappingObject}->ObjectIndexRemoveFormat(
        %Param,
        Response => $Response,
        Config   => $Param{Config},
    );
}

=head2 IndexMappingSet()

set mapping for index depending on configured fields in Object/Index module

    my $Result = $SearchObject->IndexMappingSet(
        Index => $Index,
    );

=cut

sub IndexMappingSet {
    my ( $Self, %Param ) = @_;

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search::Object');

    my $PreparedQuery = $SearchObject->QueryPrepare(
        %Param,
        Operation     => "IndexMappingSet",
        Config        => $Param{Config},
        MappingObject => $Param{MappingObject},
    );

    return 0 if !$PreparedQuery;

    my $Response = $Param{EngineObject}->QueryExecute(
        %Param,
        Query         => $PreparedQuery,
        Operation     => "IndexMappingSet",
        ConnectObject => $Param{ConnectObject},
    );

    return $Param{MappingObject}->IndexMappingSetFormat(
        %Param,
        Result => $Response,
        Config => $Param{Config},
    );
}

=head2 SQLObjectSearch()

search in sql database for objects index related

    my $Result = $SearchBaseObject->SQLObjectSearch(
        QueryParams => {
            TicketID => 1,
        },
        Fields      => ['TicketID', 'SLAID'] # optional, returns all
                                             # fields if not specified
        SortBy      => $IdentifierSQL,
        OrderBy     => "Down",  # possible: "Down", "Up",
        ResultType  => $ResultType,
        Limit       => 10,
        ReturnDefaultSQLColumnNames => 0 # (possible: 1,0) default 0, returns default column names for each of row,
                                         # when disabled it will format column names into it's aliases
    );

=cut

sub SQLObjectSearch {
    my ( $Self, %Param ) = @_;

    my $DBObject  = $Kernel::OM->Get('Kernel::System::DB');
    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    my $QueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query::$Self->{Config}->{IndexName}");

    my $IndexRealName = $Self->{Config}->{IndexRealName};
    my $Fields        = $Param{CustomIndexFields} // $Self->{Fields};
    my $ResultType    = $Param{ResultType} || 'ARRAY';

    # prepare sql statement
    my $SQL;
    my @SQLTableColumns;
    my @AliasNameTableColumns;

    if ( $ResultType eq 'COUNT' ) {
        $SQL = 'SELECT COUNT(*) FROM ' . $IndexRealName;
    }
    else {
        # set columns that will be retrieved
        if ( IsArrayRefWithData( $Param{Fields} ) ) {
            my @ParamFields = @{ $Param{Fields} };
            if ( $Param{SelectAliases} ) {
                @SQLTableColumns       = @ParamFields;
                @AliasNameTableColumns = @SQLTableColumns;
            }
            else {
                for ( my $i = 0; $i < scalar @ParamFields; $i++ ) {
                    $SQLTableColumns[$i]       = $Fields->{ $ParamFields[$i] }->{ColumnName};
                    $AliasNameTableColumns[$i] = $ParamFields[$i];
                }
            }
        }
        elsif ( IsHashRefWithData( $Param{Fields} ) ) {
            my @ParamFields = keys %{ $Param{Fields} };
            if ( $Param{SelectAliases} ) {
                @SQLTableColumns       = @ParamFields;
                @AliasNameTableColumns = @SQLTableColumns;
            }
            else {
                for ( my $i = 0; $i < scalar @ParamFields; $i++ ) {
                    $SQLTableColumns[$i]       = $Fields->{ $ParamFields[$i] }->{ColumnName};
                    $AliasNameTableColumns[$i] = $ParamFields[$i];
                }
            }
        }
        else {
            if ( $Param{SelectAliases} ) {
                @SQLTableColumns       = sort keys %{$Fields};
                @AliasNameTableColumns = @SQLTableColumns;
            }
            else {
                for my $Field ( sort keys %{$Fields} ) {
                    push @SQLTableColumns,       $Fields->{$Field}->{ColumnName};
                    push @AliasNameTableColumns, $Field;
                }
            }
        }

        $SQL = 'SELECT ' . join( ',', @SQLTableColumns ) . ' FROM ' . $IndexRealName;
    }

    my @QueryParamValues;
    my $PrependOperator;
    my @QueryConditions;

    if ( IsHashRefWithData( $Param{QueryParams} ) ) {
        my $OperatorModule = $Kernel::OM->Get("Kernel::System::Search::Object::Operators");

        my $SearchParams = $QueryObject->_QueryParamsPrepare(
            QueryParams   => $Param{QueryParams},
            NoPermissions => $Param{NoPermissions},
        );

        if ( ref $SearchParams eq 'HASH' && $SearchParams->{Error} ) {
            return {
                Success => 0,
                Data    => [],
            };
        }

        # apply search params for columns that are supported
        PARAM:
        for my $FieldName ( sort keys %{$SearchParams} ) {

            for my $OperatorData ( @{ $SearchParams->{$FieldName}->{Query} } ) {
                my $OperatorValue = $OperatorData->{Value};

                if ( !$Fields->{$FieldName}->{ColumnName} ) {
                    $LogObject->Log(
                        Priority => 'error',
                        Message =>
                            "Fallback SQL search does not support searching by $FieldName column in $IndexRealName table!"
                    );
                    return {
                        Success => 0,
                        Data    => [],
                    };
                }
                my $FieldRealName = $Fields->{$FieldName}->{ColumnName};
                my $Result        = $OperatorModule->OperatorQueryGet(
                    Field    => $Param{SelectAliases} ? $FieldName : $FieldRealName,
                    Value    => $OperatorValue,
                    Operator => $OperatorData->{Operator},
                    Object   => $Self->{Config}->{IndexName},
                    Fallback => 1,
                );

                if ( $Result->{Bindable} && IsArrayRefWithData( $Result->{BindableValue} ) ) {
                    for my $BindableValue ( @{ $Result->{BindableValue} } ) {
                        if ( ref $BindableValue eq "ARRAY" ) {
                            for my $Value ( @{$BindableValue} ) {
                                push @QueryParamValues, \$Value;
                            }
                        }
                        else {
                            push @QueryParamValues, \$BindableValue;
                        }
                    }
                }

                push @QueryConditions, $Result->{Query} if $Result->{Query};
            }
        }
    }

    # apply WHERE clause only when there are
    # at least one valid query condition
    if ( scalar @QueryConditions ) {
        $SQL .= ' WHERE ' . join( ' AND ', @QueryConditions );
        $PrependOperator = ' AND (((';
    }
    else {
        # apply WHERE for advanced params if any found
        $PrependOperator = ' WHERE (((';
    }

    my $AdvancedSQLQuery = $QueryObject->_QueryAdvancedParamsBuild(
        AdvancedQueryParams => $Param{AdvancedQueryParams},
        PrependOperator     => $PrependOperator,
        SelectAliases       => $Param{SelectAliases}
    ) // {};

    if ( $AdvancedSQLQuery->{Content} ) {
        $SQL .= $AdvancedSQLQuery->{Content};
        if ( IsArrayRefWithData( $AdvancedSQLQuery->{Binds} ) ) {
            push @QueryParamValues, @{ $AdvancedSQLQuery->{Binds} };
        }
    }

    my $SQLSortQuery = $Self->SQLSortQueryGet(
        OrderBy => $Param{OrderBy} // '',
        SortBy  => $Param{SortBy}  // '',
        ResultType    => $Param{ResultType},
        Silent        => 1,
        SelectAliases => $Param{SelectAliases}
    );

    # append query to sort data and apply order by
    $SQL .= $SQLSortQuery;

    # apply limit query
    if ( $Param{Limit} ) {
        $SQL .= " LIMIT $Param{Limit}";
    }

    if ( $Param{OnlyReturnQuery} ) {
        return {
            SQL     => $SQL,
            Bind    => \@QueryParamValues,
            Success => 1,
        };
    }

    return if !$DBObject->Prepare(
        SQL  => $SQL,
        Bind => \@QueryParamValues
    );

    my @TableColumns = $Param{ReturnDefaultSQLColumnNames} ? @SQLTableColumns : @AliasNameTableColumns;

    if ( $ResultType eq 'COUNT' ) {
        my @Count = $DBObject->FetchrowArray();
        return {
            Success => 1,
            Data    => $Count[0],
        };
    }

    my @Result;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        my %Data;
        my $DataCounter = 0;
        for my $ColumnName (@TableColumns) {
            $Data{$ColumnName} = $Row[$DataCounter];
            $DataCounter++;
        }
        push @Result, \%Data;
    }

    return {
        Success => 1,
        Data    => \@Result,
    };
}

=head2 SearchFormat()

format result specifically for index

    my $FormattedResult = $SearchBaseObject->SearchFormat(
        ResultType => 'ARRAY|HASH|COUNT' (optional, default: 'ARRAY')
        IndexName  => "Ticket",
        GloballyFormattedResult => $GloballyFormattedResult,
    )

=cut

sub SearchFormat {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    my $ResultType = $Param{ResultType};

    # define supported result types
    my $SupportedResultTypes = $Self->{SupportedResultTypes};

    if ( !$SupportedResultTypes->{ $Param{ResultType} } ) {
        $LogObject->Log(
            Priority => 'error',
            Message =>
                "Specified result type: $Param{ResultType} isn't supported! Default value: \"ARRAY\" will be used instead.",
        );

        # revert to default result type
        $Param{ResultType} = 'ARRAY';
    }

    my $IndexName               = $Self->{Config}->{IndexName};
    my $GloballyFormattedResult = $Param{GloballyFormattedResult};

    # return only number of records without formatting its attribute
    if ( $Param{ResultType} eq "COUNT" ) {
        return {
            $IndexName => $GloballyFormattedResult->{$IndexName}->{ObjectData} // 0,
        };
    }

    my $IndexResponse;

    if ( $Param{ResultType} eq "ARRAY" ) {
        $IndexResponse->{$IndexName} = $GloballyFormattedResult->{$IndexName}->{ObjectData} // [];
    }
    elsif ( $Param{ResultType} eq "HASH" ) {

        my $Identifier = $Self->{Config}->{Identifier};
        if ( !$Identifier ) {
            if ( !$Param{Silent} ) {
                $LogObject->Log(
                    Priority => 'error',
                    Message  => "Missing '\$Self->{Config}->{Identifier} for $IndexName index.'",
                );
            }
            return;
        }

        $IndexResponse = { $IndexName => {} };

        DATA:
        for my $Data ( @{ $GloballyFormattedResult->{$IndexName}->{ObjectData} } ) {
            if ( !$Data->{$Identifier} ) {
                if ( !$Param{Silent} ) {
                    $LogObject->Log(
                        Priority => 'error',
                        Message =>
                            "Could not get object identifier $Identifier for $IndexName index in the response!",
                    );
                }
                next DATA;
            }

            $IndexResponse->{$IndexName}->{ $Data->{$Identifier} } = $Data // {};
        }
    }

    return $IndexResponse;
}

=head2 ObjectListIDs()

return all sql data of object ids

    my $ResultIDs = $SearchBaseObject->ObjectListIDs();

=cut

sub ObjectListIDs {
    my ( $Self, %Param ) = @_;

    my $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::Default::$Self->{Config}->{IndexName}");
    my $Identifier  = $IndexObject->{Config}->{Identifier};

    # search for all objects
    my $SQLSearchResult = $IndexObject->SQLObjectSearch(
        QueryParams => {},
        Fields      => [$Identifier],
        OrderBy     => $Param{OrderBy},
        SortBy      => $Identifier,
        ResultType  => $Param{ResultType},
        Limit       => $Param{Limit},
    );

    # push hash data into array
    my @Result;
    if ( $SQLSearchResult->{Success} ) {
        if ( IsArrayRefWithData( $SQLSearchResult->{Data} ) ) {
            for my $SQLData ( @{ $SQLSearchResult->{Data} } ) {
                push @Result, $SQLData->{$Identifier};
            }
        }
        elsif ( $SQLSearchResult->{Data} ) {
            return $SQLSearchResult->{Data};
        }
    }

    return \@Result;
}

=head2 CustomFieldsConfig()

get all registered custom field mapping for parent index module
or specified in parameter index

    $Config = $SearchBaseObject->CustomFieldsConfig();

=cut

sub CustomFieldsConfig {
    my ( $Self, %Param ) = @_;

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');

    if ( !$Self->{Config}->{IndexName} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Need IndexName!",
        );
    }

    my $CustomPackageModuleConfigList = $ConfigObject->Get(
        "SearchEngine::Loader::Fields::$Self->{Config}->{IndexName}"
    );

    my %CustomFieldsMapping = (
        Fields => {},
        Config => {},
    );

    for my $CustomPackageConfig ( sort keys %{$CustomPackageModuleConfigList} ) {
        my $Module        = $CustomPackageModuleConfigList->{$CustomPackageConfig};
        my $PackageModule = $Kernel::OM->Get("$Module->{Module}");

        for my $Type (qw( Fields Config )) {
            if ( IsHashRefWithData( $PackageModule->{$Type} ) ) {
                %{ $CustomFieldsMapping{$Type} } = ( %{ $PackageModule->{$Type} }, %{ $CustomFieldsMapping{$Type} } );
            }
        }
    }

    return \%CustomFieldsMapping;
}

=head2 DefaultConfigGet()

get default index config

    my $Success = $SearchBaseObject->DefaultConfigGet();

=cut

sub DefaultConfigGet {
    my ( $Self, %Param ) = @_;

    # define supported result types
    $Self->{SupportedResultTypes} = {

        # key defines if result type is supported
        'ARRAY' => {

            # sortable defines if sql/engine can use
            # OrderBy, SortBy parameters in queries
            Sortable => 1,
        },
        'HASH' => {
            Sortable => 0,
        },
        'COUNT' => {
            Sortable => 0,
        }
    };

    # define default limit for search query
    $Self->{DefaultSearchLimit} = 10000;

    $Self->{SupportedOperators} = {
        Date => {
            Operator => {
                ">="             => 1,
                "="              => 1,
                "!="             => 1,
                "<="             => 1,
                "<"              => 1,
                ">"              => 1,
                "BETWEEN"        => 1,
                "IS DEFINED"     => 1,
                "IS NOT DEFINED" => 1,
            }
        },
        String => {
            Operator => {
                "="              => 1,
                "!="             => 1,
                ">="             => 1,
                "<="             => 1,
                "<"              => 1,
                ">"              => 1,
                "IS EMPTY"       => 1,
                "IS NOT EMPTY"   => 1,
                "IS DEFINED"     => 1,
                "IS NOT DEFINED" => 1,
                "FULLTEXT"       => 1,
                "PATTERN"        => 1,
            }
        },
        Integer => {
            Operator => {
                ">="             => 1,
                "="              => 1,
                "!="             => 1,
                "<="             => 1,
                "<"              => 1,
                ">"              => 1,
                "BETWEEN"        => 1,
                "IS EMPTY"       => 1,
                "IS NOT EMPTY"   => 1,
                "IS DEFINED"     => 1,
                "IS NOT DEFINED" => 1,
            }
        },
        Long => {
            Operator => {
                ">="             => 1,
                "="              => 1,
                "!="             => 1,
                "<="             => 1,
                "<"              => 1,
                ">"              => 1,
                "BETWEEN"        => 1,
                "IS EMPTY"       => 1,
                "IS NOT EMPTY"   => 1,
                "IS DEFINED"     => 1,
                "IS NOT DEFINED" => 1,
            }
        },
        Textarea => {
            Operator => {
                "FULLTEXT"       => 1,
                "IS EMPTY"       => 1,
                "IS NOT EMPTY"   => 1,
                "IS DEFINED"     => 1,
                "IS NOT DEFINED" => 1,
            }
        },
        Blob => {
            Operator => {
                "IS EMPTY"       => 1,
                "IS NOT EMPTY"   => 1,
                "IS DEFINED"     => 1,
                "IS NOT DEFINED" => 1,
            }
        },
    };

    return 1;
}

=head2 IsSortableResultType()

check if result type is sort-able

    my $Result = $SearchBaseObject->IsSortableResultType(
        ResultType => "ARRAY",
    );

=cut

sub IsSortableResultType {
    my ( $Self, %Param ) = @_;

    return $Self->{SupportedResultTypes}->{ $Param{ResultType} }->{Sortable} ? 1 : 0;
}

=head2 SortParamApply()

apply sort param if it's valid

    my $Result = $SearchBaseObject->SortParamApply(
        SortBy => 'TicketID',
        Silent => 1 # optional, possible: 0, 1
    );

=cut

sub SortParamApply {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    return if !$Param{SortBy};
    return if !$Self->{Fields}->{ $Param{SortBy} };

    my $Sortable = $Self->IsSortableResultType(
        ResultType => $Param{ResultType},
    );

    if ($Sortable) {

        # apply sorting parameter as valid
        my $SortBy = {
            Name       => $Param{SortBy},
            Properties => $Self->{Fields}->{ $Param{SortBy} },
        };

        return $SortBy;
    }

    return if $Param{Silent};

    $LogObject->Log(
        Priority => 'error',
        Message  => "Can't sort index: \"$Self->{Config}->{IndexName}\" with result type:" .
            " \"$Param{ResultType}\" by field: \"$Param{SortBy}\"." .
            " Specified result type is not sortable!\n" .
            " Sort operation won't be applied."
    );

    return;
}

=head2 SQLSortQueryGet()

return sql sort query if sort param is's valid

    my $SQLSortQuery = $SearchBaseObject->SQLSortQueryGet(
        SortBy     => $Param{SortBy},
        ResultType => $Param{ResultType},
        Silent     => 1 # optional, possible: 0, 1
    );

=cut

sub SQLSortQueryGet {
    my ( $Self, %Param ) = @_;

    my $SortBy = $Self->SortParamApply(%Param);
    return '' if !$SortBy;

    my $ColumnName = $Param{SelectAliases}
        ? $SortBy->{Name}
        : $Self->{Fields}->{ $SortBy->{Name} }->{ColumnName};

    my $SQLSortQuery = " ORDER BY $ColumnName";
    if ( $Param{OrderBy} ) {
        if ( $Param{OrderBy} eq 'Up' ) {
            $SQLSortQuery .= " ASC";
        }
        else {
            $SQLSortQuery .= " DESC";
        }
    }

    return $SQLSortQuery;
}

=head2 SearchEmptyResponse()

return empty formatted response

    my $Response = $SearchBaseObject->SearchEmptyResponse();

=cut

sub SearchEmptyResponse {
    my ( $Self, %Param ) = @_;

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');

    # format query
    my $FormattedResult = $SearchObject->SearchFormat(
        %Param,
        Result     => undef,
        IndexName  => $Self->{Config}->{IndexName},
        ResultType => $Param{ResultType} || 'ARRAY',
    );

    return $FormattedResult;
}

=head2 _Load()

load fields, custom field mapping

    my %FunctionResult = $SearchBaseObject->_Load(
        Fields => $Fields,
    );

=cut

sub _Load {
    my ( $Self, %Param ) = @_;

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search::Object');
    my $Config       = $Self->CustomFieldsConfig();

    # load custom field mapping
    %{ $Self->{Fields} } = ( %{ $Param{Fields} }, %{ $Config->{Fields} } );
    %{ $Self->{Config} } = ( %{ $Param{Config} }, %{ $Config->{Config} } );

    $Self->{OperatorMapping} = $SearchObject->{DefaultOperatorMapping};

    return 1;
}

1;
