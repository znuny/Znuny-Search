# --
# Copyright (C) 2012-2022 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Mapping;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Log',
);

=head1 NAME

Kernel::System::Search::Mapping - common mapping backend functions

=head1 DESCRIPTION

This module should be used as a parent for specified engines
in Kernel::System::Search::Mapping::"EngineName" module.

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $MappingObject = $Kernel::OM->Get('Kernel::System::Search::Mapping');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=head2 IndexMappingResultFormat()

format result from engine response

=cut

sub IndexMappingResultFormat {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    $LogObject->Log(
        Priority => 'error',
        Message  => "IndexMappingResultFormat function was not properly overriden.",
    );

    return {
        Error => 1
    };
}

=head2 ResultFormat()

format result from engine response

=cut

sub ResultFormat {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    $LogObject->Log(
        Priority => 'error',
        Message  => "ResultFormat function was not properly overriden.",
    );

    return {
        Error => 1
    };
}

=head2 Search()

process query data to structure that will be used to execute query

=cut

sub Search {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    $LogObject->Log(
        Priority => 'error',
        Message  => "Search function was not properly overriden.",
    );

    return {
        Error => 1
    };

}

=head2 ObjectIndexAdd()

process query data to structure that will be used to execute query

=cut

sub ObjectIndexAdd {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    $LogObject->Log(
        Priority => 'error',
        Message  => "ObjectIndexAdd function was not properly overriden.",
    );

    return {
        Error => 1
    };

}

=head2 ObjectIndexGet()

process query data to structure that will be used to execute query

=cut

sub ObjectIndexGet {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    $LogObject->Log(
        Priority => 'error',
        Message  => "ObjectIndexGet function was not properly overriden.",
    );

    return {
        Error => 1
    };
}

=head2 ObjectIndexRemove()

process query data to structure that will be used to execute query

=cut

sub ObjectIndexRemove {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    $LogObject->Log(
        Priority => 'error',
        Message  => "ObjectIndexRemove function was not properly overriden.",
    );

    return {
        Error => 1
    };
}

1;
