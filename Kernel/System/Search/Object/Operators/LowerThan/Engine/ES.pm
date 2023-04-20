# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Operators::LowerThan::Engine::ES;

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

    my $Value = {
        bool => {
            should => [],
        }
    };

    for my $ParamValue ( @{ $Param{Value} } ) {
        push @{ $Value->{bool}->{should} }, {
            range => {
                $Param{Field} => {
                    lt => $ParamValue,
                }
            }
        };
    }

    return {
        Query   => $Value,
        Section => 'must',
    };
}

1;
