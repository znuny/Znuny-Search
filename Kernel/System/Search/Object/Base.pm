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

    my $EmptyData = $Param{ResultType} eq 'HASH_SIMPLE' ? {} : [];

    my $SQLSearchResult = {
        Success => 0,
        Data    => $EmptyData,
    };

    if ( IsHashRefWithData( $Param{Fields} ) ) {
        $SQLSearchResult = $Self->SQLObjectSearch(
            QueryParams         => $Param{QueryParams},
            AdvancedQueryParams => $Param{AdvancedQueryParams},
            Limit               => $Param{Limit} || $Self->{DefaultSearchLimit},
            OrderBy             => $Param{OrderBy},
            SortBy              => $Param{SortBy},
            ResultType          => $Param{ResultType},
            Fields              => $Param{Fields},
            Silent              => $Param{Silent},
            IgnoreDynamicFields         => $Param{IgnoreDynamicFields},    # Ticket/CustomerUser index compatibility
            IgnoreArticles              => $Param{IgnoreArticles},         # Ticket index compatibility
            NoPermissions               => $Param{NoPermissions},
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

=head2 IndexBaseInit()

perform initialization for index

    my $Result = $SearchObject->IndexBaseInit(
        Index         => $Index,
        Config        => $Config,
        MappingObject => $MappingObject,
        EngineObject  => $EngineObject,
        ConnectObject => $ConnectObject,
    );

=cut

sub IndexBaseInit {
    my ( $Self, %Param ) = @_;

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search::Object');

    my $PreparedQuery = $SearchObject->QueryPrepare(
        %Param,
        Operation     => "IndexBaseInit",
        Config        => $Param{Config},
        MappingObject => $Param{MappingObject},
    );

    return 0 if !$PreparedQuery;

    my $Response = $Param{EngineObject}->QueryExecute(
        %Param,
        Query         => $PreparedQuery,
        Operation     => "IndexBaseInit",
        ConnectObject => $Param{ConnectObject},
    );

    return $Param{MappingObject}->IndexBaseInitFormat(
        %Param,
        Result => $Response,
        Config => $Param{Config},
    );
}

=head2 IndexBaseCheck()

Checks index for specific base conditions to determine if it can be used.
Definition only, specify your own function in Kernel::System::Search::Object::Engine::*SearchEngine*::*IndexName*.

    my $Result = $SearchObject->IndexBaseCheck(
        Index         => $Index,
        Config        => $Config,
        MappingObject => $MappingObject,
        EngineObject  => $EngineObject,
        ConnectObject => $ConnectObject,
    );

=cut

sub IndexBaseCheck {
    my ( $Self, %Param ) = @_;

    return {
        Success => 1,
    };
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
        Offset      => 2,
        ReturnDefaultSQLColumnNames => 0 # (possible: 1,0) default 0, returns default column names for each of row,
                                         # when disabled it will format column names into its aliases
    );

=cut

sub SQLObjectSearch {
    my ( $Self, %Param ) = @_;

    my $DBObject  = $Kernel::OM->Get('Kernel::System::DB');
    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    my $QueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query::$Self->{Config}->{IndexName}");

    my $Table      = $Param{Table} || $Self->{Config}->{IndexRealName};
    my $Fields     = $Param{CustomIndexFields} // $Self->{Fields};
    my $ResultType = $Param{ResultType} || 'ARRAY';

    my $EmptyData = $ResultType eq 'HASH_SIMPLE' ? {} : [];

    # prepare sql statement
    my $SQL;
    my @SQLTableColumns;
    my @AliasNameTableColumns;

    if ( $ResultType eq 'COUNT' ) {
        $SQL = 'SELECT COUNT(*) FROM ' . $Table;
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

        my $SQLJoin = '';

        if ( $Param{Join} ) {
            $SQLJoin .= ' ';
            for ( my $i = 0; $i < scalar @AliasNameTableColumns; $i++ ) {
                my $Column = $AliasNameTableColumns[$i];
                if ( $Self->{ExternalFields}->{$Column} ) {
                    $SQLTableColumns[$i]
                        = $Param{Join}->{Table} . '.' . $Self->{ExternalFields}->{$Column}->{ColumnName};
                }
                else {
                    $SQLTableColumns[$i] = $Table . '.' . $Self->{Fields}->{$Column}->{ColumnName};
                }
            }
            $SQLJoin .= "$Param{Join}->{Type} $Param{Join}->{Table} ON $Param{Join}->{On} ";
        }

        $SQL = 'SELECT ' . join( ',', @SQLTableColumns ) . ' FROM ' . $Table . $SQLJoin;
    }

    my @QueryParamValues;
    my $PrependOperator;
    my @QueryConditions;

    if ( IsHashRefWithData( $Param{QueryParams} ) ) {
        my $OperatorModule = $Kernel::OM->Get("Kernel::System::Search::Object::Operators");

        my $SearchParams = $QueryObject->_QueryParamsPrepare(
            QueryParams   => $Param{QueryParams},
            NoPermissions => $Param{NoPermissions},
            Strict        => $Param{Strict},
            QueryFor      => 'SQL',
        );

        if ( ref $SearchParams eq 'HASH' && $SearchParams->{Error} ) {
            return {
                Success => 0,
                Data    => $EmptyData,
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
                            "Fallback SQL search does not support searching by $FieldName column in $Table table!"
                    );
                    return {
                        Success => 0,
                        Data    => $EmptyData,
                    };
                }
                my $FieldRealName = $Fields->{$FieldName}->{ColumnName};

                if ( $Param{Join} ) {
                    if ( $Self->{ExternalFields}->{$FieldName} ) {
                        $FieldRealName
                            = $Param{Join}->{Table} . '.' . $Self->{ExternalFields}->{$FieldName}->{ColumnName};
                    }
                    else {
                        $FieldRealName = $Table . '.' . $Self->{Fields}->{$FieldName}->{ColumnName};
                    }
                }

                my $Result = $OperatorModule->OperatorQueryGet(
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

    # apply offset query
    if ( $Param{Offset} ) {
        $SQL .= " OFFSET $Param{Offset}";
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

    my $Result;

    if ( $ResultType eq 'ARRAY_SIMPLE' ) {
        while ( my @Row = $DBObject->FetchrowArray() ) {
            my $DataCounter = 0;
            for my $ColumnName (@TableColumns) {
                push @{$Result}, $Row[$DataCounter];
                $DataCounter++;
            }
        }
    }
    elsif ( $ResultType eq 'HASH_SIMPLE' ) {
        while ( my @Row = $DBObject->FetchrowArray() ) {
            my $DataCounter = 0;
            for my $ColumnName (@TableColumns) {
                $Result->{ $Row[$DataCounter] } = 1;
                $DataCounter++;
            }
        }
    }
    else {
        while ( my @Row = $DBObject->FetchrowArray() ) {
            my %Data;
            my $DataCounter = 0;
            for my $ColumnName (@TableColumns) {
                $Data{$ColumnName} = $Row[$DataCounter];
                $DataCounter++;
            }
            push @{$Result}, \%Data;
        }
    }

    $Result = $EmptyData if ( !$Result );

    return {
        Success => 1,
        Data    => $Result,
    };
}

=head2 SearchFormat()

format result specifically for index

    my $FormattedResult = $SearchBaseObject->SearchFormat(
        ResultType => 'ARRAY|ARRAY_SIMPLE|HASH|HASH_SIMPLE|COUNT' (optional, default: 'ARRAY')
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

    if ( $Param{ResultType} eq 'ARRAY' || $Param{ResultType} eq 'ARRAY_SIMPLE' ) {
        $IndexResponse->{$IndexName} = $GloballyFormattedResult->{$IndexName}->{ObjectData} // [];
    }
    elsif ( $Param{ResultType} eq 'HASH_SIMPLE' ) {
        $IndexResponse->{$IndexName} = $GloballyFormattedResult->{$IndexName}->{ObjectData} // {};
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
        QueryParams => $Param{QueryParams} || {},
        Fields      => [$Identifier],
        OrderBy     => $Param{OrderBy},
        SortBy      => $Param{SortBy} // $Identifier,
        ResultType  => $Param{ResultType} || 'ARRAY_SIMPLE',
        Limit       => $Param{Limit},
        Offset      => $Param{Offset},
    );

    my @Result;
    if ( $SQLSearchResult->{Success} ) {
        return $SQLSearchResult->{Data} if defined $SQLSearchResult->{Data};
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
        # result type with array of objects
        'ARRAY' => {

            # sortable defines if sql/engine can use
            # OrderBy, SortBy parameters in queries
            Sortable => 1,
        },

        # result type with array of scalars
        'ARRAY_SIMPLE' => {
            Sortable => 1,
        },

        # result type with keys as id and values as object
        'HASH' => {
            Sortable => 0,
        },

        # result type with simple hash
        'HASH_SIMPLE' => {
            Sortable => 0,
        },

        # result type as scalar
        'COUNT' => {
            Sortable => 0,
        }
    };

    # define default limit for search query
    $Self->{DefaultSearchLimit} = 10000;

    $Self->{SupportedOperators} = {
        Operator => {
            Date => {
                ">="             => 1,
                "="              => 1,
                "!="             => 1,
                "<="             => 1,
                "<"              => 1,
                ">"              => 1,
                "BETWEEN"        => 1,
                "IS DEFINED"     => 1,
                "IS NOT DEFINED" => 1,
                "WILDCARD"       => 1,
            },
            String => {
                "="              => 1,
                "!="             => 1,
                ">="             => 1,
                "<="             => 1,
                "<"              => 1,
                ">"              => 1,
                "BETWEEN"        => 1,
                "IS EMPTY"       => 1,
                "IS NOT EMPTY"   => 1,
                "IS DEFINED"     => 1,
                "IS NOT DEFINED" => 1,
                "FULLTEXT"       => 1,
                "PATTERN"        => 1,
                "WILDCARD"       => 1,
            },
            Integer => {
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
                "WILDCARD"       => 1,
            },
            Long => {
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
                "WILDCARD"       => 1,
            },
            Textarea => {
                "FULLTEXT"       => 1,
                "IS EMPTY"       => 1,
                "IS NOT EMPTY"   => 1,
                "IS DEFINED"     => 1,
                "IS NOT DEFINED" => 1,
                "WILDCARD"       => 1,
            },
            Blob => {
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

apply sort param if its valid

    my $Result = $SearchBaseObject->SortParamApply(
        SortBy     => 'TicketID',
        ResultType => $ResultType,
        Silent     => 1 # optional, possible: 0, 1
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
            OrderBy    => $Param{OrderBy},
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

    my $ColumnName;
    if ( $Param{SelectAliases} ) {
        $ColumnName = $SortBy->{Name};
    }
    else {
        $ColumnName = $Self->{Fields}->{ $SortBy->{Name} }->{ColumnName};

        if ( $Param{Join} ) {
            if ( $Self->{ExternalFields}->{ $SortBy->{Name} } ) {
                $ColumnName = $Param{Join}->{Table} . '.' . $Self->{ExternalFields}->{ $SortBy->{Name} }->{ColumnName};
            }
            else {
                $ColumnName = $Self->{Config}->{IndexName} . '.' . $Self->{Fields}->{ $SortBy->{Name} }->{ColumnName};
            }
        }
    }

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

=head2 ObjectIndexQueueHandle()

handle saved queue for index

    my $Result = $SearchBaseObject->ObjectIndexQueueHandle(
        TTL => 180,
        IndexName => 'Ticket',
        RebuildedObjectQueries => {
            Failed => 0,
            Success => 0,
        },
    );

=cut

sub ObjectIndexQueueHandle {
    my ( $Self, %Param ) = @_;

    my $LogObject         = $Kernel::OM->Get('Kernel::System::Log');
    my $SearchObject      = $Kernel::OM->Get('Kernel::System::Search');
    my $SearchChildObject = $Kernel::OM->Get('Kernel::System::Search::Object');

    for my $Needed (qw(IndexName RebuildedObjectQueries)) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    my $IndexName = $Param{IndexName};

    # get queued data for indexing
    my $Queue = $SearchChildObject->IndexObjectQueueGet(
        Index => $IndexName,
    );

    return if !defined $Queue;

    # delete queue as new data can be inserted
    # and it is already stored here
    my $Success = $SearchChildObject->IndexObjectQueueDelete(
        Index => $IndexName,
    );

    my @QueuesToExecute = $Self->ObjectIndexQueueFormat(
        Queue => $Queue,
    );

    for ( my $i = 0; $i < scalar @QueuesToExecute; $i++ ) {
        my %QueueData = %{ $QueuesToExecute[$i] };

        my $FunctionName = $QueueData{Operation};
        my %Query        = $QueueData{QueryParams}
            ?
            (
            QueryParams => $QueueData{QueryParams},
            )
            :
            (
            ObjectID => $QueueData{ObjectID},
            );

        %QueueData = ( %QueueData, %Query );

        my $AdditionalData = delete $QueueData{Data};

        if ( IsHashRefWithData($AdditionalData) ) {
            %QueueData = ( %QueueData, %{$AdditionalData} );
        }

        my $Success = $SearchObject->$FunctionName(
            Index   => $IndexName,
            Refresh => 1,
            %QueueData,
        );

        if ( !defined $Success ) {
            $Param{RebuildedObjectQueries}->{Failed}++;
        }
        else {
            $Param{RebuildedObjectQueries}->{Success}++;
        }
    }

    return 1;
}

=head2 ObjectIndexQueueFormat()

format queue data structure

    my @Queue = $SearchBaseObject->ObjectIndexQueueFormat(
        Queue => $QueueData,
    );

=cut

sub ObjectIndexQueueFormat {
    my ( $Self, %Param ) = @_;

    return if !IsHashRefWithData( $Param{Queue} );

    my @FormattedQueue;

    my $ObjectIDsQueue = $Param{Queue}->{ObjectID};
    if ( IsHashRefWithData($ObjectIDsQueue) ) {
        for my $ObjectID ( sort keys %{$ObjectIDsQueue} ) {
            my $DataToPush = $ObjectIDsQueue->{$ObjectID}->[0];
            $DataToPush->{ObjectID} = $ObjectID;
            push @FormattedQueue, $DataToPush;
        }
    }

    my $QueryParamsQueue = $Param{Queue}->{QueryParams};
    if ( IsHashRefWithData($QueryParamsQueue) ) {
        for my $QueryContext (
            sort { $QueryParamsQueue->{$a}->[0]->{Order} <=> $QueryParamsQueue->{$b}->[0]->{Order} }
            keys %{$QueryParamsQueue}
            )
        {
            push @FormattedQueue, $QueryParamsQueue->{$QueryContext}->[0];
        }
    }

    return @FormattedQueue;
}

=head2 ObjectIndexQueueApplyRules()

apply rules for indexation queue - rules are needed
to reduce requests

    my $Changed = $SearchBaseObject->ObjectIndexQueueApplyRules(
        QueueToAdd => $QueueToAdd,
        Queue      => $Queue,
    );

=cut

sub ObjectIndexQueueApplyRules {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    if ( !$Param{QueueToAdd} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter 'QueueToAdd' is needed!",
        );
        return;
    }

    my $Changed;
    my $Order      = ++$Param{Queue}->{LastOrder};
    my $QueueToAdd = $Param{QueueToAdd};
    my $Function   = $QueueToAdd->{Operation};

    if ( $Function eq 'ObjectIndexAdd' ) {
        $Changed = $Self->ObjectIndexQueueAddRule(
            Queue      => $Param{Queue},
            QueueToAdd => $QueueToAdd,
            Order      => $Order,
        );
    }
    elsif ( $Function eq 'ObjectIndexSet' ) {
        $Changed = $Self->ObjectIndexQueueSetRule(
            Queue      => $Param{Queue},
            QueueToAdd => $QueueToAdd,
            Order      => $Order,
        );
    }
    elsif ( $Function eq 'ObjectIndexUpdate' ) {
        $Changed = $Self->ObjectIndexQueueUpdateRule(
            Queue      => $Param{Queue},
            QueueToAdd => $QueueToAdd,
            Order      => $Order,
        );
    }
    elsif ( $Function eq 'ObjectIndexRemove' ) {
        $Changed = $Self->ObjectIndexQueueRemoveRule(
            Queue      => $Param{Queue},
            QueueToAdd => $QueueToAdd,
            Order      => $Order,
        );
    }

    return $Changed;
}

=head2 ObjectIndexQueueAddRule()

apply index object add rule for queries

    my $Success = $SearchBaseObject->ObjectIndexQueueAddRule(
        Queue      => $Queue,
        QueueToAdd => $QueueToAdd,
    );

=cut

sub ObjectIndexQueueAddRule {
    my ( $Self, %Param ) = @_;

    my $LogObject         = $Kernel::OM->Get('Kernel::System::Log');
    my $SearchChildObject = $Kernel::OM->Get('Kernel::System::Search::Object');
    return if !IsHashRefWithData( $Param{QueueToAdd} );

    my $ObjectIDQueueToAdd    = $Param{QueueToAdd}->{ObjectID};
    my $QueryParamsQueueToAdd = $Param{QueueToAdd}->{QueryParams};

    my $Index = $Self->{Config}->{IndexName};

    # check if ObjectIndexAdd by object id is to be queued
    if ($ObjectIDQueueToAdd) {
        my $QueuedOperation = $Param{Queue}->{ObjectID}->{$ObjectIDQueueToAdd}->[-1];
        if ($QueuedOperation) {

            # identify what operation was already queued
            my $PrevQueuedOperationName = $QueuedOperation->{Operation};

            # same object don't need to be added 2 times
            if ( $PrevQueuedOperationName eq 'ObjectIndexAdd' ) {
                return 0;
            }

            # update needs to be overwritten by add
            elsif ( $PrevQueuedOperationName eq 'ObjectIndexUpdate' ) {
                return 2 if $SearchChildObject->IndexObjectQueueUpdate(
                    %{ $Param{QueueToAdd} },
                    ID => $QueuedOperation->{ID},
                );
            }

            # set doesn't need to be overwritten
            elsif ( $PrevQueuedOperationName eq 'ObjectIndexSet' ) {
                return 0;
            }

            # should never be a case in the system, don't allow it
            elsif ( $PrevQueuedOperationName eq 'ObjectIndexRemove' ) {
                return 0;
            }
        }
        else {
            return 1 if $SearchChildObject->IndexObjectQueueAdd(
                %{ $Param{QueueToAdd} },
                Index => $Self->{Config}->{IndexName},
            );
        }
    }

    # check if ObjectIndexAdd by query params is to be queued
    elsif ($QueryParamsQueueToAdd) {

        my $Context = $Param{QueueToAdd}->{Context};
        if ( !$Context ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Parameter 'Context' inside 'QueueToAdd' hash is needed!",
            );
            return;
        }

        my $QueuedOperation = $Param{Queue}->{QueryParams}->{$Context}->[-1];

        if ($QueuedOperation) {
            return 2 if $SearchChildObject->IndexObjectQueueUpdate(
                %{ $Param{QueueToAdd} },
                ID    => $QueuedOperation->{ID},
                Order => $Param{Order},
            );
        }
        else {
            return 1 if $SearchChildObject->IndexObjectQueueAdd(
                %{ $Param{QueueToAdd} },
                Index => $Self->{Config}->{IndexName},
                Order => $Param{Order},
            );
        }
    }
    else {
        return;
    }

    return;
}

=head2 ObjectIndexQueueSetRule()

apply index object set rule for queries

    my $Success = $SearchBaseObject->ObjectIndexQueueSetRule(
        Queue      => $Queue,
        QueueToAdd => $QueueToAdd,
    );

=cut

sub ObjectIndexQueueSetRule {
    my ( $Self, %Param ) = @_;

    my $LogObject         = $Kernel::OM->Get('Kernel::System::Log');
    my $SearchChildObject = $Kernel::OM->Get('Kernel::System::Search::Object');
    return if !IsHashRefWithData( $Param{QueueToAdd} );

    my $ObjectIDQueueToAdd    = $Param{QueueToAdd}->{ObjectID};
    my $QueryParamsQueueToAdd = $Param{QueueToAdd}->{QueryParams};

    # check if ObjectIndexSet by object id is to be queued
    if ($ObjectIDQueueToAdd) {
        my $QueuedOperation = $Param{Queue}->{ObjectID}->{$ObjectIDQueueToAdd}->[-1];
        if ($QueuedOperation) {

            # identify what operation was already queued
            my $PrevQueuedOperationName = $QueuedOperation->{Operation};

            # set overrides add
            if ( $PrevQueuedOperationName eq 'ObjectIndexAdd' ) {
                return 2 if $SearchChildObject->IndexObjectQueueUpdate(
                    %{ $Param{QueueToAdd} },
                    ID => $QueuedOperation->{ID},
                );
            }

            # update needs to be overwritten
            elsif ( $PrevQueuedOperationName eq 'ObjectIndexUpdate' ) {
                return 2 if $SearchChildObject->IndexObjectQueueUpdate(
                    %{ $Param{QueueToAdd} },
                    ID => $QueuedOperation->{ID},
                );
            }

            # set doesn't need to be overwritten
            elsif ( $PrevQueuedOperationName eq 'ObjectIndexSet' ) {
                return;
            }

            # should never be a case in the system, don't allow it
            elsif ( $PrevQueuedOperationName eq 'ObjectIndexRemove' ) {
                return;
            }
        }
        else {
            return 1 if $SearchChildObject->IndexObjectQueueAdd(
                %{ $Param{QueueToAdd} },
                Index => $Self->{Config}->{IndexName},
            );
        }
    }

    # check if ObjectIndexSet by query params is to be queued
    elsif ($QueryParamsQueueToAdd) {

        my $Context = $Param{QueueToAdd}->{Context};
        if ( !$Context ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Parameter 'Context' inside 'QueueToAdd' hash is needed!",
            );
            return;
        }

        my $QueuedOperation = $Param{Queue}->{QueryParams}->{$Context}->[-1];

        if ($QueuedOperation) {
            return 2 if $SearchChildObject->IndexObjectQueueUpdate(
                %{ $Param{QueueToAdd} },
                ID    => $QueuedOperation->{ID},
                Order => $Param{Order},
            );
        }
        else {
            return 1 if $SearchChildObject->IndexObjectQueueAdd(
                %{ $Param{QueueToAdd} },
                Index => $Self->{Config}->{IndexName},
                Order => $Param{Order},
            );
        }
    }
    else {
        return;
    }

    return;
}

=head2 ObjectIndexQueueUpdateRule()

apply index object update rule for queries

    my $Success = $SearchBaseObject->ObjectIndexQueueUpdateRule(
        Queue      => $Queue,
        QueueToAdd => $QueueToAdd,
    );

=cut

sub ObjectIndexQueueUpdateRule {
    my ( $Self, %Param ) = @_;

    my $LogObject         = $Kernel::OM->Get('Kernel::System::Log');
    my $SearchChildObject = $Kernel::OM->Get('Kernel::System::Search::Object');
    return if !IsHashRefWithData( $Param{QueueToAdd} );

    my $ObjectIDQueueToAdd    = $Param{QueueToAdd}->{ObjectID};
    my $QueryParamsQueueToAdd = $Param{QueueToAdd}->{QueryParams};

    # check if ObjectIndexUpdate by object id is to be queued
    if ($ObjectIDQueueToAdd) {
        my $QueuedOperation = $Param{Queue}->{ObjectID}->{$ObjectIDQueueToAdd}->[-1];
        if ($QueuedOperation) {

            # update does not override any previous operation
            return;
        }
        else {
            return 1 if $SearchChildObject->IndexObjectQueueAdd(
                %{ $Param{QueueToAdd} },
                Index => $Self->{Config}->{IndexName},
            );
        }
    }

    # check if ObjectIndexUpdate by query params is to be queued
    elsif ($QueryParamsQueueToAdd) {

        my $Context = $Param{QueueToAdd}->{Context};
        if ( !$Context ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Parameter 'Context' inside 'QueueToAdd' hash is needed!",
            );
            return;
        }

        my $QueuedOperation = $Param{Queue}->{QueryParams}->{$Context}->[-1];

        if ($QueuedOperation) {
            return 2 if $SearchChildObject->IndexObjectQueueUpdate(
                %{ $Param{QueueToAdd} },
                ID    => $QueuedOperation->{ID},
                Order => $Param{Order},
            );
        }
        else {
            return 1 if $SearchChildObject->IndexObjectQueueAdd(
                %{ $Param{QueueToAdd} },
                Index => $Self->{Config}->{IndexName},
                Order => $Param{Order},
            );
        }
    }
    else {
        return;
    }

    return;
}

=head2 ObjectIndexQueueRemoveRule()

apply index object update rule for queries

    my $Success = $SearchBaseObject->ObjectIndexQueueRemoveRule(
        Queue      => $Queue,
        QueueToAdd => $QueueToAdd,
    );

=cut

sub ObjectIndexQueueRemoveRule {
    my ( $Self, %Param ) = @_;

    my $LogObject         = $Kernel::OM->Get('Kernel::System::Log');
    my $SearchChildObject = $Kernel::OM->Get('Kernel::System::Search::Object');
    return if !IsHashRefWithData( $Param{QueueToAdd} );

    my $ObjectIDQueueToAdd    = $Param{QueueToAdd}->{ObjectID};
    my $QueryParamsQueueToAdd = $Param{QueueToAdd}->{QueryParams};

    # check if ObjectIndexRemove by object id is to be queued
    if ($ObjectIDQueueToAdd) {
        my $QueuedOperation = $Param{Queue}->{ObjectID}->{$ObjectIDQueueToAdd}->[-1];
        if ($QueuedOperation) {

            # identify what operation was already queued
            my $PrevQueuedOperationName = $QueuedOperation->{Operation};

            # remove cancels add
            if ( $PrevQueuedOperationName eq 'ObjectIndexAdd' ) {
                return 3 if $SearchChildObject->IndexObjectQueueDelete(
                    ID => $QueuedOperation->{ID},
                );
            }

            # remove overwrites update
            elsif ( $PrevQueuedOperationName eq 'ObjectIndexUpdate' ) {
                return 2 if $SearchChildObject->IndexObjectQueueUpdate(
                    %{ $Param{QueueToAdd} },
                    ID => $QueuedOperation->{ID},
                );
            }

            # remove overwrites set
            elsif ( $PrevQueuedOperationName eq 'ObjectIndexSet' ) {
                return 2 if $SearchChildObject->IndexObjectQueueUpdate(
                    %{ $Param{QueueToAdd} },
                    ID => $QueuedOperation->{ID},
                );
            }

            # should never be a case in the system, don't allow it
            elsif ( $PrevQueuedOperationName eq 'ObjectIndexRemove' ) {
                return;
            }
        }
        else {
            return 1 if $SearchChildObject->IndexObjectQueueAdd(
                %{ $Param{QueueToAdd} },
                Index => $Self->{Config}->{IndexName},
            );
        }
    }

    # check if ObjectIndexRemove by query params is to be queued
    elsif ($QueryParamsQueueToAdd) {

        my $Context = $Param{QueueToAdd}->{Context};
        if ( !$Context ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Parameter 'Context' inside 'QueueToAdd' hash is needed!",
            );
            return;
        }

        my $QueuedOperation = $Param{Queue}->{QueryParams}->{$Context}->[-1];

        if ($QueuedOperation) {
            return 2 if $SearchChildObject->IndexObjectQueueUpdate(
                %{ $Param{QueueToAdd} },
                ID    => $QueuedOperation->{ID},
                Order => $Param{Order},
            );
        }
        else {
            return 1 if $SearchChildObject->IndexObjectQueueAdd(
                %{ $Param{QueueToAdd} },
                Index => $Self->{Config}->{IndexName},
                Order => $Param{Order},
            );
        }
    }
    else {
        return;
    }

    return;
}

=head2 FieldsInvertedFormat()

format fields hash to be inverted by column name

    my $InvertedFields = $SearchBaseObject->FieldsInvertedFormat();

=cut

sub FieldsInvertedFormat {
    my ( $Self, %Param ) = @_;

    return $Self->{InvertedFields} if $Self->{InvertedFields};

    my $Fields = $Self->{Fields};
    my %InvertedFields;

    if ( IsHashRefWithData($Fields) ) {
        for my $Field ( sort keys %{$Fields} ) {
            $InvertedFields{ $Fields->{$Field}->{ColumnName} } = {
                %{ $Fields->{$Field} },
                FieldName => $Field,
            };
        }

        $Self->{InvertedFields} = \%InvertedFields;
    }

    return $Self->{InvertedFields} // {};
}

=head2 CustomFunction()

execute custom function

    my $Success = $SearchBaseObject->CustomFunction(%Param);

=cut

sub CustomFunction {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(Name Params)) {

        next NEEDED if defined $Param{CustomFunction}->{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed in CustomFunction parameter!",
        );
        return;
    }

    my $FunctionName = $Param{CustomFunction}->{Name};

    my $Result = $Self->$FunctionName(
        %Param,
        CustomFunction => undef,
        Params         => $Param{CustomFunction}->{Params},
        FunctionName   => $FunctionName,
    );

    return $Result;
}

=head2 LoadSettings()

load object settings for index

    my $Settings = $SearchBaseObject->LoadSettings(
        IndexName => 'Ticket',
    );

=cut

sub LoadSettings {
    my ( $Self, %Param ) = @_;

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');

    my $IndexSettings = {};
    return $IndexSettings if !$SearchObject->{Config}->{ActiveEngine};

    if ( !$Param{IndexName} ) {

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter 'IndexName' is needed!",
        );

        return $IndexSettings;
    }

    my $SettingsConfig = $ConfigObject->Get(
        "SearchEngine::Settings::Index::$SearchObject->{Config}->{ActiveEngine}::$Param{IndexName}"
    );

    if ( IsHashRefWithData($SettingsConfig) ) {

        # priority of settings is supported
        for my $Setting ( sort values %{$SettingsConfig} ) {
            %{$IndexSettings} = ( %{$IndexSettings}, %{$Setting} );
        }
    }

    return $IndexSettings;
}

=head2 _Load()

load fields, custom field mapping

    my %FunctionResult = $SearchBaseObject->_Load(
        Fields => $Fields,
        Config => $Config,
    );

=cut

sub _Load {
    my ( $Self, %Param ) = @_;

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search::Object');

    if ( $Param{CustomConfigNotSupported} ) {
        $Self->{Fields} = $Param{Fields};
    }
    else {
        my $Config = $Self->CustomFieldsConfig();

        %{ $Self->{Config} } = ( %{ $Param{Config} }, %{ $Config->{Config} } );

        # load custom field mapping
        %{ $Self->{Fields} } = ( %{ $Param{Fields} }, %{ $Config->{Fields} } );
    }

    $Self->{OperatorMapping} = $SearchObject->{DefaultOperatorMapping};

    return 1;
}

=head2 _BaseCheckIndexOperation()

base check for index operation

    my $Result = $SearchBaseObject->_BaseCheckIndexOperation(
        Index => 'Ticket',
        MappingObject => $MappingObject,
        Config => $Config,
    );

=cut

sub _BaseCheckIndexOperation {
    my ( $Self, %Param ) = @_;

    my $LogObject         = $Kernel::OM->Get('Kernel::System::Log');
    my $SearchChildObject = $Kernel::OM->Get('Kernel::System::Search::Object');

    NEEDED:
    for my $Needed (qw(Index MappingObject Config)) {
        next NEEDED if defined $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    if ( $Param{ObjectID} && $Param{QueryParams} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter ObjectID and QueryParams cannot be used together!",
        );
        return;
    }
    elsif ( !$Param{ObjectID} && !$Param{QueryParams} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Either parameter ObjectID or QueryParams is needed!",
        );
        return;
    }

    my $Index = $Param{Index};

    my $IndexIsValid = $SearchChildObject->IndexIsValid(
        IndexName => $Index,
    );

    return if !$IndexIsValid;
    return 1;
}

=head2 _ObjectIndexAction()

check and send index data for specified operation, release data from memory afterwards

    my $FunctionResult = $SearchBaseObject->_ObjectIndexAddAction(
        Function => 'ObjectIndexAdd'
        DataToIndex => $DataToIndex,
        %AdditionalParams,
    );

=cut

sub _ObjectIndexAction {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(Function DataToIndex)) {

        next NEEDED if defined $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    my $DataToIndex = $Param{DataToIndex};
    return   if !$DataToIndex->{Success};
    return 0 if !IsArrayRefWithData( $DataToIndex->{Data} );
    my $Success = $Self->_ObjectIndexBaseAction(
        %Param,
        Body     => $DataToIndex->{Data},
        Function => $Param{Function},
    );

    # release data part from memory
    undef $Param{DataToIndex};
    return $Success;
}

=head2 _ObjectIndexBaseAction()

perform base operation

    my $FunctionResult = $SearchBaseObject->_ObjectIndexBaseAction(
        Function => 'ObjectIndexAdd',
        MappingObject => $MappingObject,
        EngineObject => $EngineObject,
        %AdditionalParams,
    );

=cut

sub _ObjectIndexBaseAction {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(Function MappingObject EngineObject)) {

        next NEEDED if defined $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    my $Function = $Param{Function};

    # build base query
    my $PreparedQuery = $Param{MappingObject}->$Function(
        %Param,
    );

    return 0 if !$PreparedQuery;

    my $Response = $Param{EngineObject}->QueryExecute(
        %Param,
        Operation     => $Function,
        Query         => $PreparedQuery,
        ConnectObject => $Param{ConnectObject},
        Config        => $Param{Config},
    );

    my $FunctionFormat = $Function . 'Format';

    return $Param{MappingObject}->$FunctionFormat(
        %Param,
        Response => $Response,
        Config   => $Param{Config},
    );
}

1;
