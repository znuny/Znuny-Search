# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Operators::NotEqual::Engine::ES;

use strict;
use warnings;

our @ObjectDependencies = ();

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub QueryBuild {
    my ( $Self, %Param ) = @_;

    if ( ref $Param{Value} ne "ARRAY" ) {
        $Param{Value} = [ $Param{Value} ];
    }

    return {
        Query => {
            terms => {
                $Param{Field} . ".keyword" => $Param{Value}
            }
        },
        Section => 'must_not'
    };
}

1;
