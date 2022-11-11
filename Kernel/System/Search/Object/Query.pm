# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Query;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsHashRefWithData IsArrayRefWithData);

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Ticket',
    'Kernel::System::Search::Object::Operators',
);

=head1 NAME

Kernel::System::Search::Object::Query - search engine query lib

=head1 DESCRIPTION

Common search engine query backend functions.

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $QueryObject = $Kernel::OM->Get('Kernel::System::Search::Object::Query');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};

    #  sub-modules should include an implementation of mapping
    $Self->{IndexFields} = {};

    bless( $Self, $Type );

    return $Self;
}

=head2 Search()

create query for specified operation

    my $Result = $SearchQueryObject->Search(
        MappingObject   => $Config,
        QueryParams     => $QueryParams,
    );

=cut

sub Search {
    my ( $Self, %Param ) = @_;

    return {
        Error    => 1,
        Fallback => {
            Enable => 1
        },
    } if !$Param{MappingObject};

    my $LogObject         = $Kernel::OM->Get('Kernel::System::Log');
    my $ParamSearchObject = $Kernel::OM->Get("Kernel::System::Search::Object::$Param{Object}");

    if ( IsArrayRefWithData( $Param{AdvancedQueryParams} ) ) {

        # return the query
        my $Query = $Param{MappingObject}->AdvancedSearch(
            Limit => $Self->{IndexDefaultSearchLimit},    # default limit or override with limit from param
            %Param,
        );

        if ( !$Query ) {
            return {
                Error    => 1,
                Fallback => {
                    Enable => 1,
                },
            };
        }

        return {
            Query => $Query,
        };
    }

    my $SortBy;
    if (
        $Param{SortBy} && $Self->{IndexFields}->{ $Param{SortBy} }
        )
    {
        my $Sortable = $ParamSearchObject->IsSortableResultType(
            ResultType => $Param{ResultType},
        );

        if ($Sortable) {

            # change into real column name
            $SortBy = $Self->{IndexFields}->{ $Param{SortBy} };
        }
        else {
            if ( !$Param{Silent} ) {
                $LogObject->Log(
                    Priority => 'error',
                    Message  => "Can't sort index: \"$ParamSearchObject->{Config}->{IndexName}\" with result type:" .
                        " \"$Param{ResultType}\" by field: \"$Param{SortBy}\"." .
                        " Specified result type is not sortable!\n" .
                        " Sort operation won't be applied."
                );
            }
        }
    }

    my $SearchParams = $Self->_QueryParamsPrepare(
        QueryParams => $Param{QueryParams},
    );

    # return the query
    my $Query = $Param{MappingObject}->Search(
        Limit => $Self->{IndexDefaultSearchLimit},    # default limit or override with limit from param
        %Param,
        Fields           => $Param{Fields},
        FieldsDefinition => $Self->{IndexFields},
        QueryParams      => $SearchParams,
        SortBy           => $SortBy,
    );

    if ( !$Query ) {
        return {
            Error    => 1,
            Fallback => {
                Enable => 1,
            },
        };
    }

    return {
        Query => $Query,
    };
}

=head2 ObjectIndexAdd()

create query for specified operation

    my $Result = $SearchQueryObject->ObjectIndexAdd(
        MappingObject   => $Config,
        ObjectID        => $ObjectID,
    );

=cut

sub ObjectIndexAdd {
    my ( $Self, %Param ) = @_;

    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    NEEDED:
    for my $Needed (qw(MappingObject)) {

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
            Message  => "Parameter ObjectID or QueryParams is needed!",
        );
        return;
    }

    my $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::$Param{Index}");
    my $Identifier  = $IndexObject->{Config}->{Identifier};

    my $QueryParams = $Param{QueryParams} ? $Param{QueryParams} :
        {
        $Identifier => $Param{ObjectID}
        };

    my $SQLSearchResult = $IndexObject->SQLObjectSearch(
        QueryParams => $QueryParams,
        ResultType  => $Param{SQLSearchResultType} || 'ARRAY',
    );

    # build and return query
    return $Param{MappingObject}->ObjectIndexAdd(
        %Param,
        Body => $SQLSearchResult,
    );
}

=head2 ObjectIndexSet()

create query for specified operation

    my $Result = $SearchQueryObject->ObjectIndexSet(
        MappingObject   => $Config,
        ObjectID        => $ObjectID,
    );

=cut

sub ObjectIndexSet {
    my ( $Self, %Param ) = @_;

    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    NEEDED:
    for my $Needed (qw(MappingObject)) {

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
            Message  => "Parameter ObjectID or QueryParams is needed!",
        );
        return;
    }

    my $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::$Param{Index}");
    my $Identifier  = $IndexObject->{Config}->{Identifier};

    my $QueryParams = $Param{QueryParams} ? $Param{QueryParams} :
        {
        $Identifier => $Param{ObjectID}
        };

    my $SQLSearchResult = $IndexObject->SQLObjectSearch(
        QueryParams => $QueryParams,
        ResultType  => $Param{SQLSearchResultType} || 'ARRAY',
    );

    # build and return query
    return $Param{MappingObject}->ObjectIndexSet(
        %Param,
        Body => $SQLSearchResult,
    );
}

=head2 ObjectIndexUpdate()

create query for specified operation

    my $Result = $SearchQueryObject->ObjectIndexUpdate(
        MappingObject   => $Config,
        ObjectID        => $ObjectID,
    );

=cut

sub ObjectIndexUpdate {
    my ( $Self, %Param ) = @_;

    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    NEEDED:
    for my $Needed (qw(MappingObject)) {

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
            Message  => "Parameter ObjectID or QueryParams is needed!",
        );
        return;
    }

    my $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::$Param{Index}");
    my $Identifier  = $IndexObject->{Config}->{Identifier};

    my $QueryParams = $Param{QueryParams} ? $Param{QueryParams} :
        {
        $Identifier => $Param{ObjectID}
        };

    my $SQLSearchResult = $IndexObject->SQLObjectSearch(
        QueryParams => $QueryParams,
    );

    # build and return query
    return $Param{MappingObject}->ObjectIndexUpdate(
        %Param,
        Body => $SQLSearchResult,
    );
}

=head2 ObjectIndexRemove()

create query for specified operation

    my $Result = $SearchQueryObject->ObjectIndexRemove(
        MappingObject   => $Config,
        ObjectID        => $ObjectID,
        Config          => $Config,
        Index           => $Index,
        Body            => $Body,
    );

=cut

sub ObjectIndexRemove {
    my ( $Self, %Param ) = @_;

    return if !$Param{MappingObject};

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(Config Index)) {

        next NEEDED if defined $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    my $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::$Param{Index}");
    my $Identifier  = $IndexObject->{Config}->{Identifier};

    my $QueryParams = $Param{QueryParams} ? $Param{QueryParams} :
        {
        $Identifier => $Param{ObjectID}
        };

    $QueryParams = $Self->_QueryParamsPrepare(
        QueryParams => $QueryParams,
    );

    # build and return query
    return $Param{MappingObject}->ObjectIndexRemove(
        %Param,
        FieldsDefinition => $Self->{IndexFields},
        QueryParams      => $QueryParams,
    );
}

=head2 IndexAdd()

create query for index list operation

    my $Result = $SearchQueryObject->IndexAdd(
        MappingObject   => $MappingObject,
    );

=cut

sub IndexAdd {
    my ( $Self, %Param ) = @_;

    return if !$Param{MappingObject};

    # build and return query
    return $Param{MappingObject}->IndexAdd(
        %Param,
        IndexRealName => $Self->{IndexConfig}->{IndexRealName},
    );
}

=head2 IndexRemove()

create query for index list operation

    my $Result = $SearchQueryObject->IndexRemove(
        MappingObject   => $MappingObject,
        Index           => $Index,
    );

=cut

sub IndexRemove {
    my ( $Self, %Param ) = @_;

    return if !$Param{MappingObject};

    # build and return query
    return $Param{MappingObject}->IndexRemove(
        %Param,
        IndexRealName => $Self->{IndexConfig}->{IndexRealName} // $Param{IndexRealName},
    );
}

=head2 IndexList()

create query for index list operation

    my $Result = $SearchQueryObject->IndexList(
        MappingObject   => $MappingObject,
    );

=cut

sub IndexList {
    my ( $Self, %Param ) = @_;

    return if !$Param{MappingObject};

    # build and return query
    return $Param{MappingObject}->IndexList(
        %Param,
    );
}

=head2 IndexClear()

create query for index clearing operation

    my $Result = $SearchQueryObject->IndexClear(
        MappingObject   => $MappingObject,
        Index           => "Ticket",
    );

=cut

sub IndexClear {
    my ( $Self, %Param ) = @_;

    return if !$Param{MappingObject};

    # build and returns the query
    return $Param{MappingObject}->IndexClear(
        %Param,
    );
}

=head2 DiagnosticDataGet()

create query for index clearing operation

    my $Result = $SearchQueryObject->DiagnosticDataGet(
        MappingObject   => $MappingObject,
        Index           => "Ticket",
    );

=cut

sub DiagnosticDataGet {
    my ( $Self, %Param ) = @_;

    return if !$Param{MappingObject};

    # returns the query
    return $Param{MappingObject}->DiagnosticDataGet(
        %Param,
    );
}

=head2 IndexMappingGet()

create query for index mapping get operation

    my $Result = $SearchQueryObject->IndexMappingGet(
        MappingObject   => $MappingObject,
    );

=cut

sub IndexMappingGet {
    my ( $Self, %Param ) = @_;

    return if !$Param{MappingObject};

    # returns the query
    return $Param{MappingObject}->IndexMappingGet(
        %Param,
        IndexRealName => $Self->{IndexConfig}->{IndexRealName},
    );
}

=head2 IndexMappingSet()

create query for index mapping set operation

    my $Result = $SearchQueryObject->IndexMappingSet(
        MappingObject   => $MappingObject,
    );

=cut

sub IndexMappingSet {
    my ( $Self, %Param ) = @_;

    return if !$Param{MappingObject};

    # returns the query
    return $Param{MappingObject}->IndexMappingSet(
        %Param,
        Fields      => $Self->{IndexFields},
        IndexConfig => $Self->{IndexConfig},
    );
}

=head2 IndexInitialSettingsGet()

create query for index initial setting receive

    my $Result = $SearchQueryObject->IndexInitialSettingsGet(
        MappingObject   => $MappingObject,
        Index => $Index,
);

=cut

sub IndexInitialSettingsGet {
    my ( $Self, %Param ) = @_;

    return if !$Param{MappingObject};

    # returns the query
    return $Param{MappingObject}->IndexInitialSettingsGet(
        %Param,
        IndexRealName => $Self->{IndexConfig}->{IndexRealName},
    );
}

=head2 IndexRefresh()

create query for refreshing index index data

    my $Result = $SearchQueryObject->IndexRefresh(
        MappingObject   => $MappingObject,
        Index => $Index,
);

=cut

sub IndexRefresh {
    my ( $Self, %Param ) = @_;

    return if !$Param{MappingObject};

    # returns the query
    return $Param{MappingObject}->IndexRefresh(
        %Param,
        IndexRealName => $Self->{IndexConfig}->{IndexRealName},
    );
}

=head2 _QueryParamsPrepare()

prepare valid structure output for query params

    my $QueryParams = $SearchQueryObject->_QueryParamsPrepare(
        QueryParams => $Param{QueryParams},
        NoMappingCheck => $Param{NoMappingCheck},
    );

=cut

sub _QueryParamsPrepare {
    my ( $Self, %Param ) = @_;

    my $ValidParams;
    PARAM:
    for my $SearchParam ( sort keys %{ $Param{QueryParams} } ) {

        # apply search params for columns that are supported
        my @Result = $Self->_QueryParamSet(
            Name           => $SearchParam,
            Value          => $Param{QueryParams}->{$SearchParam},
            NoMappingCheck => $Param{NoMappingCheck},
        );

        if ( scalar @Result ) {
            push @{ $ValidParams->{$SearchParam}->{Query} }, @Result;
        }
    }
    return $ValidParams;
}

=head2 _QueryParamSet()

set query param field to standardized output

    my $Result = $SearchQueryObject->_QueryParamSet(
        Name => $Name,
        Value => $Value,
    );

=cut

sub _QueryParamSet {
    my ( $Self, %Param ) = @_;

    my $Name  = $Param{Name};
    my $Value = $Param{Value};

    # check if there is existing mapping between query param and database column
    return if !$Self->{IndexFields}->{$Name} && !$Param{NoMappingCheck};
    my @Operators;

    if ( ref $Value eq "HASH" ) {
        @Operators = (
            {
                Operator => $Value->{Operator} || '=',
                Value    => $Value->{Value},
            }
        );
    }
    elsif (
        ref $Value eq "ARRAY"
        &&
        ref $Value->[0] eq 'HASH'
        )
    {
        @Operators = @{$Value};
    }
    else {
        @Operators = (
            {
                Operator => '=',
                Value    => $Value,
            }
        );
    }

    return @Operators;
}

=head2 _QueryAdvancedParamsBuild()

build advanced params query sql

    my $QueryParams = $SearchQueryObject->_QueryAdvancedParamsBuild(
        QueryParams => $Param{QueryParams},
    );

=cut

sub _QueryAdvancedParamsBuild {
    my ( $Self, %Param ) = @_;

    my $AdvancedQuery;

    # apply advanced search params for columns that are supported
    my $PrependOperator = '';
    if ( $Param{PrependOperator} ) {
        $PrependOperator = $Param{PrependOperator};
    }
    if ( IsArrayRefWithData( $Param{AdvancedQueryParams} ) ) {
        PARAM:
        for my $Data ( @{ $Param{AdvancedQueryParams} } ) {
            next PARAM if !IsArrayRefWithData($Data);
            DATA:
            for my $SearchParam ( @{$Data} ) {
                $AdvancedQuery = $Self->_QueryAdvancedParamBuildSQL(
                    AdvancedSQLQuery   => $AdvancedQuery,
                    AdvancedParamToSet => $SearchParam,
                    PrependOperator    => $PrependOperator,
                );
                $PrependOperator = ' AND (';
            }

            # close statement
            $AdvancedQuery->{Content} .= ')';

            # prepare OR as the next possible statement as arrays
            # next to each other on the same level are OR statements
            $PrependOperator = ' OR ((';
        }
        $AdvancedQuery->{Content} .= ')';
    }

    return $AdvancedQuery;
}

=head2 _QueryAdvancedParamBuildSQL()

builds single advanced query field

    my $Result = $SearchQueryObject->_QueryAdvancedParamBuildSQL(
        AdvancedSQLQuery   => $AdvancedSQLQuery,
        AdvancedParamToSet => $AdvancedParamToSet,
        PrependOperator    => $PrependOperator,
    );

=cut

sub _QueryAdvancedParamBuildSQL {
    my ( $Self, %Param ) = @_;

    my $AdvancedParamToSet = $Param{AdvancedParamToSet};
    my $AdvancedSQLQuery   = $Param{AdvancedSQLQuery};
    my $OperatorToPrepend  = $Param{PrependOperator};
    my $FirstOperatorSet;
    my $AdditionalSQLQuery = '';

    if ( IsHashRefWithData($AdvancedParamToSet) ) {
        my $OperatorModule = $Kernel::OM->Get("Kernel::System::Search::Object::Operators");
        for my $FieldName ( sort keys %{$AdvancedParamToSet} ) {

            # standardize structure
            my @PreparedQueryParam = $Self->_QueryParamSet(
                Name  => $FieldName,
                Value => $AdvancedParamToSet->{$FieldName},
            );

            # build sql
            for my $OperatorData (@PreparedQueryParam) {
                my $FieldRealName = $Self->{IndexFields}->{$FieldName}->{ColumnName};
                my $Result        = $OperatorModule->OperatorQueryGet(
                    Field    => $FieldRealName,
                    Value    => $OperatorData->{Value},
                    Operator => $OperatorData->{Operator},
                    Object   => $Self->{IndexConfig}->{IndexName},
                    Fallback => 1,
                    )
                    || {
                    Query => '',
                    };

                if ($FirstOperatorSet) {
                    $OperatorToPrepend = ' AND ';
                }
                $AdditionalSQLQuery .= $OperatorToPrepend . $Result->{Query};
                if ( $Result->{Bindable} ) {
                    $OperatorData->{Value} = $Result->{BindableValue} if $Result->{BindableValue};
                    push @{ $AdvancedSQLQuery->{Binds} }, \$OperatorData->{Value};
                }
                $FirstOperatorSet = 1;

            }
        }
        if ($FirstOperatorSet) {
            $AdvancedSQLQuery->{Content} .= $AdditionalSQLQuery . ')';
        }
    }
    elsif ( IsArrayRefWithData($AdvancedParamToSet) ) {

        # search inside arrays recurrently and connect them with OR statements
        for my $Queries ( @{$AdvancedParamToSet} ) {
            $AdvancedSQLQuery = $Self->_QueryAdvancedParamBuildSQL(
                PrependOperator    => ' OR (',
                AdvancedParamToSet => $Queries,
                AdvancedSQLQuery   => $AdvancedSQLQuery,
            );
        }
    }

    return $AdvancedSQLQuery;
}
1;
