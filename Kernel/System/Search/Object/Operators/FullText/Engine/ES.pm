# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Operators::FullText::Engine::ES;

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

    my %OperatorMapping = (
        'AND' => 'and',
        'OR'  => 'or'
    );

    my $ParamValue = $Param{Value};

    if ( ref $ParamValue ne "HASH" ) {
        $ParamValue = {
            query    => $ParamValue,
            operator => $OperatorMapping{AND},
        };
    }
    else {
        $ParamValue = {
            query    => $ParamValue->{Text},
            operator => $OperatorMapping{ $Param{Value}->{QueryOperator} || 'AND' },
        };
    }

    if ( ref( $ParamValue->{query} ) ne 'ARRAY' ) {
        $ParamValue->{query} = [ $ParamValue->{query} ];
    }

    my $Value = {
        bool => {
            should => []
        }
    };

    for my $QueryValue ( @{ $ParamValue->{query} } ) {
        push @{ $Value->{bool}->{should} }, {
            match => {
                $Param{Field} => {
                    query    => $QueryValue,
                    operator => $ParamValue->{operator},
                }
            }
        };
    }

    return {
        Query   => $Value,
        Section => 'must'
    };
}

1;
