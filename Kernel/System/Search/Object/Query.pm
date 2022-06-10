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

Kernel::System::Search::Object::Query - TO-DO

=head1 DESCRIPTION

TO-DO

=head1 PUBLIC INTERFACE


=head2 new()

TO-DO

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=head2 ObjectIndexAdd()

TO-DO

=cut

sub ObjectIndexAdd {
    my ( $Type, %Param ) = @_;

    return 1;
}

=head2 ObjectIndexGet()

TO-DO

=cut

sub ObjectIndexGet {
    my ( $Type, %Param ) = @_;

    return 1;
}

=head2 ObjectIndexRemove()

TO-DO

=cut

sub ObjectIndexRemove {
    my ( $Type, %Param ) = @_;

    return 1;
}

=head2 Search()

TO-DO

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
