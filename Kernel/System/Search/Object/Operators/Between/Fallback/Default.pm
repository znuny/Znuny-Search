# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Operators::Between::Fallback::Default;

use strict;
use warnings;
use Kernel::System::VariableCheck qw(IsHashRefWithData);

our @ObjectDependencies = ();

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub QueryBuild {
    my ( $Self, %Param ) = @_;

    if ( !IsHashRefWithData( $Param{Value} ) ) {
        return;
    }

    return {
        Query         => "$Param{Field} BETWEEN ? AND ?",
        Bindable      => 1,
        BindableValue => [ $Param{Value}->{From}, $Param{Value}->{To} ],
    };
}

1;
