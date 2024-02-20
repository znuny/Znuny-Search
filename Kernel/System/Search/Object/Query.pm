# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
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
    'Kernel::System::DynamicField',
    'Kernel::System::DynamicField::Backend',
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
        Fields          => $Fields,
        MappingObject   => $MappingObject,
        NoPermissions   => 0,
        %SearchParams,
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

    # no need to fallback if fields from
    # parameter aren't valid for the object
    return {
        Error => 1,
    } if ( !IsHashRefWithData( $Param{Fields} ) );

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

    my $ParamSearchObject = $Kernel::OM->Get("Kernel::System::Search::Object::Default::$Param{Object}");

    my $SortBy = $ParamSearchObject->SortParamApply(
        %Param,
    );

    my $SearchParams = $Self->_QueryParamsPrepare(
        QueryParams   => $Param{QueryParams},
        NoPermissions => $Param{NoPermissions},
        QueryFor      => 'Engine',
    );

    if ( ref $SearchParams eq 'HASH' && $SearchParams->{Error} ) {
        return {
            Error    => 1,
            Fallback => {
                Enable => 1,
            },
        };
    }

    # return the query
    my $Query = $Param{MappingObject}->Search(
        Limit => $Self->{IndexDefaultSearchLimit},    # default limit or override with limit from param
        %Param,
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
            Message  => "Either parameter ObjectID or QueryParams is needed!",
        );
        return;
    }

    my $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::Default::$Param{Index}");
    my $Identifier  = $IndexObject->{Config}->{Identifier};

    my $QueryParams = $Param{QueryParams} ? $Param{QueryParams} : {
        $Identifier => $Param{ObjectID},
    };

    my $SQLSearchResult = $IndexObject->SQLObjectSearch(
        %Param,
        QueryParams => $QueryParams,
        Strict      => 1,
    );

    return   if !$SQLSearchResult->{Success};
    return 0 if !IsArrayRefWithData( $SQLSearchResult->{Data} );

    # build and return query
    return $Param{MappingObject}->ObjectIndexAdd(
        %Param,
        Body => $SQLSearchResult->{Data},
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
            Message  => "Either parameter ObjectID or QueryParams is needed!",
        );
        return;
    }

    my $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::Default::$Param{Index}");
    my $Identifier  = $IndexObject->{Config}->{Identifier};

    my $QueryParams = $Param{QueryParams} ? $Param{QueryParams} : {
        $Identifier => $Param{ObjectID},
    };

    my $SQLSearchResult = $IndexObject->SQLObjectSearch(
        %Param,
        QueryParams => $QueryParams,
        Strict      => 1,
    );

    return   if !$SQLSearchResult->{Success};
    return 0 if !IsArrayRefWithData( $SQLSearchResult->{Data} );

    # build and return query
    return $Param{MappingObject}->ObjectIndexSet(
        %Param,
        Body => $SQLSearchResult->{Data},
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
            Message  => "Either parameter ObjectID or QueryParams is needed!",
        );
        return;
    }

    my $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::Default::$Param{Index}");
    my $Identifier  = $IndexObject->{Config}->{Identifier};

    my $QueryParams = $Param{QueryParams} ? $Param{QueryParams} : {
        $Identifier => $Param{ObjectID},
    };

    my $SQLSearchResult;
    if ( $Param{Data} ) {
        $SQLSearchResult = {
            Success => 1,
            Data    => $Param{Data},
        };
    }
    else {
        $SQLSearchResult = $IndexObject->SQLObjectSearch(
            %Param,
            QueryParams => $QueryParams,
            Strict      => 1,
        );
    }

    return   if !$SQLSearchResult->{Success};
    return 0 if !IsArrayRefWithData( $SQLSearchResult->{Data} );

    # build and return query
    return $Param{MappingObject}->ObjectIndexUpdate(
        %Param,
        Body => $SQLSearchResult->{Data},
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

    my $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::Default::$Param{Index}");
    my $Identifier  = $IndexObject->{Config}->{Identifier};

    my $QueryParams = $Param{QueryParams} ? $Param{QueryParams} : {
        $Identifier => $Param{ObjectID},
    };

    $QueryParams = $Self->_QueryParamsPrepare(
        QueryParams   => $QueryParams,
        NoPermissions => $Param{NoPermissions},
        QueryFor      => 'Engine',
    );

    return if ref $QueryParams eq 'HASH' && $QueryParams->{Error};

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
        IndexRealName  => $Self->{IndexConfig}->{IndexRealName},
        Fields         => $Self->{IndexFields},
        IndexConfig    => $Self->{IndexConfig},
        ExternalFields => $Self->{IndexExternalFields},
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
        Fields         => $Self->{IndexFields},
        IndexConfig    => $Self->{IndexConfig},
        ExternalFields => $Self->{IndexExternalFields},
    );
}

=head2 IndexBaseInit()

create query for index init operation

    my $Result = $SearchQueryObject->IndexBaseInit(
        MappingObject   => $MappingObject,
    );

=cut

sub IndexBaseInit {
    my ( $Self, %Param ) = @_;

    return if !$Param{MappingObject};

    # returns the query
    return $Param{MappingObject}->IndexBaseInit(
        %Param,
        Fields         => $Self->{IndexFields},
        IndexConfig    => $Self->{IndexConfig},
        ExternalFields => $Self->{IndexExternalFields},
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

=head2 EngineQueryHelperObjCreate()

create object that can build queries for active engine

    my $SearchQueryObject = $SearchQueryObject->EngineQueryHelperObjCreate(
        IndexName => 'Ticket',
        Query     => {
            Body => {'query' => {}},
            Method => 'POST',
        },
    )
);

=cut

sub EngineQueryHelperObjCreate {
    my ( $Self, %Param ) = @_;

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');

    return if $SearchObject->{Fallback};

    my $Module = "Kernel::System::Search::Object::EngineQueryHelper::$Self->{ActiveEngine}";

    my $QueryEngineHelperObj = $Module->new(
        IndexName => $Param{IndexName},
        Query     => $Param{Query},
    );

    return $QueryEngineHelperObj;
}

=head2 _QueryParamsPrepare()

prepare valid structure output for query params

    my $QueryParams = $SearchQueryObject->_QueryParamsPrepare(
        QueryParams    => $Param{QueryParams},
        NoMappingCheck => $Param{NoMappingCheck},
        NoPermissions  => 1, # optional, skip permissions check
    );

=cut

sub _QueryParamsPrepare {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(QueryFor)) {

        next NEEDED if defined $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    my $ValidParams;
    my $SimplifiedMode   = $Self->{IndexSupportedOperators}->{SimplifiedMode}->{ $Param{QueryFor} };
    my $SearchableFields = $Self->{IndexSearchableFields}->{ $Param{QueryFor} };

    PARAM:
    for my $SearchParam ( sort keys %{ $Param{QueryParams} } ) {

        # apply search params for columns that are supported
        my $Result = $Self->_QueryParamSet(
            Name             => $SearchParam,
            Value            => $Param{QueryParams}->{$SearchParam},
            NoMappingCheck   => $Param{NoMappingCheck},
            SimplifiedMode   => $SimplifiedMode,
            SearchableFields => $SearchableFields,
            QueryFor         => $Param{QueryFor},
            Strict           => $Param{Strict},
        );

        if ( IsArrayRefWithData($Result) ) {
            push @{ $ValidParams->{$SearchParam}->{Query} }, @{$Result};
        }
        elsif ( ref $Result eq 'HASH' && $Result->{Error} ) {
            return $Result;
        }
    }

    return $ValidParams;
}

=head2 _QueryParamSet()

set query param field to standardized output

    my @Result = $SearchQueryObject->_QueryParamSet(
        Name => $Name,
        Value => $Value,
        QueryFor => 'SQL', # possible: 'Engine', 'SQL'
        SimplifiedMode => '0', # optional, prevent using operators
    );

=cut

sub _QueryParamSet {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    my $Name = $Param{Name};

    # prevent using query parameter that is not supposed to be searched by
    # this feature is not used in any of core indexes
    # meaning that any fields in the index mapping can be used as a query parameter
    return { Error => 1 }
        if $Param{SearchableFields} && $Param{SearchableFields} ne '*' && !$Param{SearchableFields}->{$Name};

    my $Value     = $Param{Value};
    my $IndexName = $Self->{IndexConfig}->{IndexName};

    my $SearchQueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query::$IndexName");

    my $Data = $SearchQueryObject->_QueryFieldDataSet(
        Name     => $Name,
        QueryFor => $Param{QueryFor},
    );

    # check if query param should pass
    my $ParamIsValid = $Self->_QueryFieldCheck(
        Name           => $Name,
        Value          => $Value,
        Data           => $Data,
        NoMappingCheck => $Param{NoMappingCheck},
    );

    if ( !$ParamIsValid ) {

        # if param is supposed to pass
        # and it failed, then return error
        # response which can identify usage of
        # wrong query parameter
        if ( $Param{Strict} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Search parameter: $Name is not valid!",
            );
            return { Error => 1 };
        }

        # otherwise simply ignore this parameter
        else {
            return;
        }
    }

    if ( !defined $Data ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Data is needed!",
        );
        return { Error => 1 };
    }

    # if no value is defined ignore query parameter
    if ( !defined $Value ) {
        return;
    }

    NEEDED:
    for my $Needed (qw(Type ReturnType)) {

        next NEEDED if $Data->{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "'$Needed' is needed in Data hash!",
        );
        return { Error => 1 };
    }

    my $Type       = $Data->{Type};
    my $ReturnType = $Data->{ReturnType};

    my @Operators;

    if ( ref $Value eq "HASH" ) {
        if ( $Param{SimplifiedMode} ) {
            $LogObject->Log(
                Priority => 'error',
                Message =>
                    "Query parameter $Name is specified in a hash which is not allowed for index $Self->{IndexConfig}->{IndexName}!",
            );
            return { Error => 1 };
        }

        @Operators = (
            {
                Operator   => $Value->{Operator} || '=',
                Value      => $Value->{Value},
                ReturnType => $ReturnType,
                Type       => $Type,
            }
        );
    }
    elsif (
        ref $Value eq "ARRAY"
        &&
        ref $Value->[0] eq 'HASH'
        )
    {
        if ( $Param{SimplifiedMode} ) {
            $LogObject->Log(
                Priority => 'error',
                Message =>
                    "Query parameter $Name is specified in an array of hashes which is not allowed for index $Self->{IndexConfig}->{IndexName}!",
            );
            return { Error => 1 };
        }
        for my $Value ( @{$Value} ) {
            $Value->{ReturnType} = $ReturnType;
            $Value->{Type}       = $Type;
        }
        @Operators = @{$Value};
    }
    else {
        @Operators = (
            {
                Operator   => '=',
                Value      => $Value,
                ReturnType => $ReturnType,
                Type       => $Type,
            }
        );
    }

    # check operator validity
    OPERATOR:
    for ( my $i = 0; $i < scalar @Operators; $i++ ) {
        my $OperatorData = $Operators[$i];

        if ( !$OperatorData->{Operator} ) {
            delete $Operators[$i];
            next OPERATOR;
        }

        if ( !$Self->{IndexSupportedOperators}->{Operator}->{$Type}->{ $OperatorData->{Operator} } ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Query parameter $Name type $Type does not support operator $OperatorData->{Operator}!",
            );
            return { Error => 1 };
        }
    }

    # clear undefs of possibly deleted values
    @Operators = grep {$_} @Operators;

    return \@Operators;
}

=head2 _QueryFieldCheck()

check specified field for index

    my $Result = $SearchQueryObject->_QueryFieldCheck(
        Name => 'SLAID',
        Value => '1', # by default value is passed but is not used
                      # in standard query module
    );

=cut

sub _QueryFieldCheck {
    my ( $Self, %Param ) = @_;

    # by default check if field is in index fields and mapping check is enabled
    return if !$Self->{IndexFields}->{ $Param{Name} } && !$Param{NoMappingCheck};
    return 1;
}

=head2 _QueryFieldDataSet()

set data for field

    my $Result = $SearchQueryObject->_QueryFieldDataSet(
        Name => 'SLAID',
    );

=cut

sub _QueryFieldDataSet {
    my ( $Self, %Param ) = @_;

    my $DefaultValue = {
        ReturnType => 'SCALAR',
    };
    my $Data = $DefaultValue;

    if ( $Param{Name} eq '_id' ) {
        $Data->{Type} = 'String';
        return $DefaultValue;
    }

    if ( $Self->{IndexFields}->{ $Param{Name} } ) {
        for my $Property (qw(Type ReturnType)) {
            if ( $Self->{IndexFields}->{ $Param{Name} }->{$Property} ) {
                $Data->{$Property} = $Self->{IndexFields}->{ $Param{Name} }->{$Property};
            }
        }
    }
    elsif ( $Self->{IndexExternalFields}->{ $Param{Name} } ) {
        for my $Property (qw(Type ReturnType)) {
            if ( $Self->{IndexExternalFields}->{ $Param{Name} }->{$Property} ) {
                $Data->{$Property} = $Self->{IndexExternalFields}->{ $Param{Name} }->{$Property};
            }
        }
    }

    return $Data;
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
                    SelectAliases      => $Param{SelectAliases},
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
                    Field    => $Param{SelectAliases} ? $FieldName : $FieldRealName,
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
                    if ( ref $OperatorData->{Value} eq "ARRAY" ) {
                        for my $Value ( @{ $OperatorData->{Value} } ) {
                            push @{ $AdvancedSQLQuery->{Binds} }, \$Value;
                        }
                    }
                    else {
                        push @{ $AdvancedSQLQuery->{Binds} }, \$OperatorData->{Value};
                    }
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
                SelectAliases      => $Param{SelectAliases},
            );
        }
    }

    return $AdvancedSQLQuery;
}

=head2 _QueryDynamicFieldInfoGet()

get info for dynamic field in query params

    my $Result = $SearchQueryObject->_QueryDynamicFieldInfoGet(
        DynamicFieldConfig => $DynamicFieldConfig,
    );

=cut

sub _QueryDynamicFieldInfoGet {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(DynamicFieldConfig)) {

        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    my $DynamicFieldObject        = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

    my $DynamicFieldConfig     = $Param{DynamicFieldConfig};
    my $DynamicFieldColumnName = 'DynamicField_' . $DynamicFieldConfig->{Name};

    # get return type for dynamic field
    my $FieldValueType = $DynamicFieldBackendObject->TemplateValueTypeGet(
        DynamicFieldConfig => $DynamicFieldConfig,
        FieldType          => 'Edit',
    );

    # set type of field
    my $Type = 'String';

    if (
        $DynamicFieldConfig->{FieldType}
        && (
            $DynamicFieldConfig->{FieldType} eq 'Date'
            || $DynamicFieldConfig->{FieldType} eq 'DateTime'
        )
        )
    {
        $Type = 'Date';
    }

    # apply properties that are set in object fields mapping
    return {
        ColumnName => $DynamicFieldColumnName,
        Name       => $DynamicFieldConfig->{Name},
        ReturnType => $FieldValueType->{$DynamicFieldColumnName} || 'SCALAR',
        Type       => $Type,
    };
}
1;
