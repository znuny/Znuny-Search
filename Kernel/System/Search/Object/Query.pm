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
    'Kernel::System::Search::Mapping::ES'
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
    bless( $Self, $Type );

    return $Self;
}

=head2 ObjectIndexAdd()

create query for specified operation

=cut

sub ObjectIndexAdd {
    my ( $Type, %Param ) = @_;

    return 1;
}

=head2 ObjectIndexUpdate()

create query for specified operation

=cut

sub ObjectIndexUpdate {
    my ( $Type, %Param ) = @_;

    return 1;
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

    # Returns the query
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

    # Returns the query
    my $Query = $MappingObject->Search(
        %Param
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

1;
