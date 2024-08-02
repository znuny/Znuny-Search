# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Operators::Equal::Engine::ES;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::Search::Mapping::ES'
);

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub QueryBuild {
    my ( $Self, %Param ) = @_;

    my $SearchMappingESObject = $Kernel::OM->Get('Kernel::System::Search::Mapping::ES');

    if ( ref $Param{Value} ne "ARRAY" ) {
        $Param{Value} = [ $Param{Value} ];
    }

    # ignore empty array
    return { Ignore => 1 } if !defined $Param{Value}->[0];

    my $FieldName = $SearchMappingESObject->QueryFieldNameBuild(
        Type => $Param{FieldType},
        Name => $Param{Field},
    );

    # if expected response is an array, then search by arrays
    if ( $Param{ReturnType} && $Param{ReturnType} eq 'ARRAY' ) {
        if ( IsArrayRefWithData( $Param{Value}->[0] ) ) {
            my $Query;
            for my $Values ( @{ $Param{Value} } ) {
                push @{ $Query->{bool}->{should} }, {
                    terms_set => {
                        $FieldName => {
                            terms                       => $Values,
                            minimum_should_match_script => {
                                source => "1"
                            }
                        }
                    }
                };
            }
            return {
                Query   => $Query,
                Section => 'must'
            };
        }
        else {
            return {
                Query => {
                    terms_set => {
                        $Param{Field} . '.keyword' => {
                            terms                       => $Param{Value},
                            minimum_should_match_script => {
                                source => "1"
                            }
                        }
                    }
                },
                Section => 'must'
            };
        }
    }

    return {
        Query => {
            terms => {
                $FieldName => $Param{Value}
            }
        },
        Section => 'must'
    };
}

1;
