# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Operators::Base;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::Search',
);

=head1 NAME

Kernel::System::Search::Object::Operators::Base - search operators base lib

=head1 DESCRIPTION

Common base backend functions for operators.

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $SearchOperators = $Kernel::OM->Get('Kernel::System::Search::Object::Operators::Base');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=head2 OperatorQueryBuild()

build query for engine/fallback search call using operator

    my $Result = $SearchBaseObject->OperatorQueryBuild(
        Field              => $Field,
        Value              => $Value,
        Fallback           => 1, # possible: 1, 0
        OperatorModuleName => "Equal" # possible - every operator name, base operators:
                                      # "GreaterEqualThan", "GreaterThan", "Equal",
                                      # "LowerEqualThan", "LowerThan",
                                      # "IsDefined", "IsNotDefined",
                                      # "IsEmpty", "IsNotEmpty".
    );

=cut

sub OperatorQueryBuild {
    my ( $Self, %Param ) = @_;

    if ( $Param{Fallback} ) {

        # build fallback query
        my $FallbackOperatorModule
            = "Kernel::System::Search::Object::Operators::$Param{OperatorModuleName}::Fallback::Default";
        my $FallbackOperatorObject = $Kernel::OM->Get("$FallbackOperatorModule");

        return $FallbackOperatorModule->QueryBuild(%Param);
    }

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');

    # build engine query
    my $EngineOperatorModule
        = "Kernel::System::Search::Object::Operators::$Param{OperatorModuleName}::Engine::$SearchObject->{Config}->{ActiveEngine}";
    my $EngineOperatorObject = $Kernel::OM->Get("$EngineOperatorModule");

    return $EngineOperatorObject->QueryBuild(%Param);
}

1;
