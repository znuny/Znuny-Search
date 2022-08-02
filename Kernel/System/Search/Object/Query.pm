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

use Kernel::System::VariableCheck qw(IsHashRefWithData);

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Ticket',
);

=head1 NAME

Kernel::System::Search::Object::Query - common query backend functions

=head1 DESCRIPTION

TO-DO

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

=head2 ObjectIndexAdd()

create query for specified operation

    my $Result = $QueryTicketObject->ObjectIndexAdd(
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
        return {
            Error    => 1,
            Fallback => {
                Enable => 0
            },
        };
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

    # build query
    my $Query = $Param{MappingObject}->ObjectIndexAdd(
        %Param,
        Body => $ObjectData,
    );

    if ( !$Query ) {

        # TO-DO
    }

    return {
        Error    => 0,
        Query    => $Query,
        Fallback => {
            Enable => 0
        },
    };
}

=head2 ObjectIndexUpdate()

create query for specified operation

    my $Result = $QueryTicketObject->ObjectIndexUpdate(
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
        return {
            Error    => 1,
            Fallback => {
                Enable => 0
            },
        };
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

    # build query
    my $Query = $Param{MappingObject}->ObjectIndexUpdate(
        %Param,
        Body => $ObjectData
    );

    if ( !$Query ) {

        # TO-DO
    }

    return {
        Error    => 0,
        Query    => $Query,
        Fallback => {
            Enable => 0
        },
    };
}

=head2 ObjectIndexGet()

create query for specified operation

=cut

sub ObjectIndexGet {
    my ( $Type, %Param ) = @_;

    return 1;
}

=head2 ObjectIndexRemove()

create query for specified operation

    my $Result = $QueryObject->ObjectIndexRemove(
        MappingObject   => $Config,
        ObjectID        => $ObjectID,
        Config          => $Config,
        Index           => $Index,
        Body            => $Body,
    );

=cut

sub ObjectIndexRemove {
    my ( $Type, %Param ) = @_;

    return {
        Error    => 1,
        Fallback => {
            Enable => 0
        },
    } if !$Param{MappingObject};

    my $MappingObject = $Param{MappingObject};

    # returns the query
    my $Query = $MappingObject->ObjectIndexRemove(
        %Param
    );

    if ( !$Query ) {

        # TO-DO
    }

    return {
        Error    => 0,
        Query    => $Query,
        Fallback => {
            Enable => 0
        },
    };
}

=head2 Search()

create query for specified operation

    my $Result = $QueryObject->Search(
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

    my $MappingObject = $Param{MappingObject};

    my %SearchParams;

    # return columns that are supported
    for my $SearchParam ( sort keys %{ $Param{QueryParams} } ) {
        $SearchParams{ $Self->{IndexFields}->{$SearchParam} } = $Param{QueryParams}->{$SearchParam};
    }

    # returns the query
    my $Query = $MappingObject->Search(
        %Param,
        QueryParams => \%SearchParams
    );

    if ( !$Query ) {
        return {
            Error    => 1,
            Fallback => {
                Enable => 1
            },
        };
    }

    return {
        Error    => 0,
        Query    => $Query,
        Fallback => {
            Enable => 0
        },
    };
}

=head2 IndexClear()

create query for index clearing operation

    my $Result = $QueryObject->IndexClear(
        MappingObject   => $MappingObject,
        QueryParams     => $QueryParams,
    );

=cut

sub IndexClear {
    my ( $Type, %Param ) = @_;

    return {
        Error    => 1,
        Fallback => {
            Enable => 0
        },
    } if !$Param{MappingObject};

    my $MappingObject = $Param{MappingObject};

    # Returns the query
    my $Query = $MappingObject->IndexClear(
        %Param
    );

    return {
        Error    => 1,
        Fallback => {
            Enable => 0
        },
    } if !$Query->{Body};

    return {
        Error    => 0,
        Query    => $Query,
        Fallback => {
            Enable => 0
        },
    };
}

1;
