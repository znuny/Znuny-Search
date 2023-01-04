# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Operators;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::Search::Object::Operators::Base',
    'Kernel::System::Log',
);

=head1 NAME

Kernel::System::Search::Object::Operators - search object operators lib

=head1 DESCRIPTION

Common base backend functions for operators.

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $SearchOperators = $Kernel::OM->Get('Kernel::System::Search::Object::Operators');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=head2 OperatorQueryGet()

main function to get query for specific operator

    my $Result = $SearchOperatorsObject->OperatorQueryGet(
        Field              => $Field,
        Value              => $Value,
        Fallback           => 1, # possible: 1, 0
        Operator           => '>',
    );

=cut

sub OperatorQueryGet {
    my ( $Self, %Param ) = @_;

    my $IndexModule = $Kernel::OM->Get("Kernel::System::Search::Object::Query::$Param{Object}");

    my $IndexOperatorModule = $Kernel::OM->Get(
        "Kernel::System::Search::Object::Operators::Base"
    );

    my $Result = $IndexOperatorModule->OperatorQueryBuild(
        Field              => $Param{Field},
        Value              => $Param{Value},
        Fallback           => $Param{Fallback},
        ReturnType         => $Param{ReturnType},
        OperatorModuleName => $IndexModule->{IndexOperatorMapping}->{ $Param{Operator} }
    );

    return $Result;
}

1;
