# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Base;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Log',
);

=head1 NAME

Kernel::System::Search::Object::Base - common base backend functions

=head1 DESCRIPTION

TO-DO

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $SearchBaseObject = $Kernel::OM->Get('Kernel::System::Search::Object::Base');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=head2 Fallback()

TO-DO

=cut

sub Fallback {
    my ( $Self, %Param ) = @_;

    return {
        Error => 1
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

    # Return array ref as default.
    $Param{ResultType} ||= 'ARRAY';

    my $IndexName               = $Param{IndexName};
    my $GloballyFormattedResult = $Param{GloballyFormattedResult};

    my $IndexResponse;

    if ( $Param{ResultType} eq "COUNT" ) {
        $IndexResponse->{$IndexName} = scalar @{ $GloballyFormattedResult->{$IndexName}->{ObjectData} };
    }
    elsif ( $Param{ResultType} eq "ARRAY" ) {
        $IndexResponse->{$IndexName} = $GloballyFormattedResult->{$IndexName}->{ObjectData};
    }
    elsif ( $Param{ResultType} eq "HASH" ) {
        my $Identifier = $Self->{ResultFormat}->{Identifier};
        if ( !$Identifier ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Missing '\$Self->{ResultFormat}->{Identifier} for $IndexName index.'",
            );
            return;
        }

        DATA:
        for my $Data ( @{ $GloballyFormattedResult->{$IndexName}->{ObjectData} } ) {
            if ( !$Data->{$Identifier} ) {
                $LogObject->Log(
                    Priority => 'error',
                    Message  => "Could not get object identifier: $Identifier for index: $IndexName in the response!",
                );
                next DATA;
            }

            $IndexResponse->{$IndexName}->{ $Data->{$Identifier} } = $Data;
        }
    }

    return $IndexResponse;
}

sub IndexObjectGetFormat {
    my ( $Self, %Param ) = @_;
    return {};
}

sub IndexObjectAddFormat {
    my ( $Self, %Param ) = @_;
    return {};
}

sub IndexObjectRemoveFormat {
    my ( $Self, %Param ) = @_;
    return {};
}

=head2 ObjectListIDs()

    Receive list of ObjectIDs stored by otrs system database site.

    my @Result = $Object->ObjectListIDs();

=cut

sub ObjectListIDs {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    $LogObject->Log(
        Priority => 'error',
        Message  => "ObjectListIDs() function was not properly overriden.",
    );

    return {
        Error => 1
    };
}

1;
