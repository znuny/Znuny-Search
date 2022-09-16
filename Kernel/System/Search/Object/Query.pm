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

TO-DO: delete later
Developer note: most conditions needs to be met with fallback
alternative (Kernel::System::Search::Object::Base->SQLObjectSearch()).

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

    my %SearchParams;

    # apply search params for columns that are supported
    PARAM:
    for my $SearchParam ( sort keys %{ $Param{QueryParams} } ) {

        # check if there is existing mapping between query param and database column
        next PARAM if !$Self->{IndexFields}->{$SearchParam};

        # do not accept undef values for param
        next PARAM if !defined $Param{QueryParams}->{$SearchParam};
        $SearchParams{$SearchParam} = $Param{QueryParams}->{$SearchParam};

        my $QueryParamType = $Self->{IndexFields}->{$SearchParam}->{Type};
        my $QueryParamValue;
        my $QueryParamOperator;

        if ( ref $Param{QueryParams}->{$SearchParam} eq "HASH" ) {
            $QueryParamValue    = $Param{QueryParams}->{$SearchParam}->{Value};
            $QueryParamOperator = $Param{QueryParams}->{$SearchParam}->{Operator} || '=';
        }
        else {
            $QueryParamValue    = $Param{QueryParams}->{$SearchParam};
            $QueryParamOperator = "=";
        }

        if ( !$Self->{IndexSupportedOperators}->{$QueryParamType}->{Operator}->{$QueryParamOperator} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Operator '$QueryParamOperator' is not supported for '$QueryParamType' type.",
            );

            return {
                Error => 1,
            };
        }
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

    my @Fields;

    if ( IsArrayRefWithData() ) {
        @Fields = @{ $Param{Fields} };
    }
    else {
        @Fields = keys %{ $ParamSearchObject->{Fields} };
    }

    # return the query
    my $Query = $Param{MappingObject}->Search(
        Limit => $Self->{IndexDefaultSearchLimit},    # default limit or override with limit from param
        %Param,
        Fields           => \@Fields,
        FieldsDefinition => $Self->{IndexFields},
        QueryParams      => \%SearchParams,
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
    for my $Needed (qw(MappingObject ObjectID)) {

        next NEEDED if defined $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    my $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::$Param{Index}");
    my $Identifier  = $IndexObject->{Config}->{Identifier};

    my $SearchParams = {
        $Identifier => $Param{ObjectID},
    };

    # search for object with specified id
    my $SQLSearchResult = $IndexObject->SQLObjectSearch(
        QueryParams => $SearchParams,
    );

    # result should contain one object within array
    my $ObjectData = $SQLSearchResult->[0];

    # build and return query
    return $Param{MappingObject}->ObjectIndexAdd(
        %Param,
        Body => $ObjectData,
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
    for my $Needed (qw(MappingObject ObjectID)) {

        next NEEDED if defined $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    my $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::$Param{Index}");
    my $Identifier  = $IndexObject->{Config}->{Identifier};

    my $SearchParams = {
        $Identifier => $Param{ObjectID},
    };

    # search for object with specified id
    my $SQLSearchResult = $IndexObject->SQLObjectSearch(
        QueryParams => $SearchParams,
    );

    # result should contain one object within array
    my $ObjectData = $SQLSearchResult->[0];

    # build and return query
    return $Param{MappingObject}->ObjectIndexUpdate(
        %Param,
        Body => $ObjectData,
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

    # build and return query
    return $Param{MappingObject}->ObjectIndexRemove(
        %Param,
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
        IndexRealName => $Self->{IndexConfig}->{IndexRealName},
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

1;
