# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Operators::Equal::Fallback::Default;

use strict;
use warnings;
use Kernel::System::VariableCheck qw(IsArrayRefWithData);

our @ObjectDependencies = ();

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub QueryBuild {
    my ( $Self, %Param ) = @_;

    my @ParamValue = IsArrayRefWithData( $Param{Value} ) ? @{ $Param{Value} } : ( $Param{Value} );

    @ParamValue = map {"'$_'"} @ParamValue;

    my $Value = join( ', ', @ParamValue );
    return {
        Query    => "$Param{Field} IN ($Value)",
        Bindable => 0,
    };
}

1;
