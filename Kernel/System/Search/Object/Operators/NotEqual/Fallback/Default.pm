# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Operators::NotEqual::Fallback::Default;

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

    my @ParamBindQuery = map {'?,'} @ParamValue;
    chop $ParamBindQuery[-1];

    return {
        Query         => "$Param{Field} NOT IN (@ParamBindQuery)",
        Bindable      => 1,
        BindableValue => \@ParamValue,
    };
}

1;
