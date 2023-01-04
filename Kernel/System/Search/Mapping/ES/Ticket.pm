# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Mapping::ES::Ticket;

use strict;
use warnings;
use MIME::Base64;

use parent qw( Kernel::System::Search::Mapping::ES );

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::Encode',
);

=head1 NAME

Kernel::System::Search::Mapping::ES::Ticket - elastic search mapping lib

=head1 DESCRIPTION

Functions to map parameters from/to query/response to API functions.

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $SearchMappingESObject = $Kernel::OM->Get('Kernel::System::Search::Mapping::ES');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=head2  _ResponseDataFormat()

globally formats response data from engine

    my $Result = $SearchMappingESObject->_ResponseDataFormat(
        Result => $Result,
        QueryData => $QueryData,
    );

=cut

sub _ResponseDataFormat {
    my ( $Self, %Param ) = @_;

    my @Objects;

    my $EncodeObject = $Kernel::OM->Get('Kernel::System::Encode');

    if ( IsArrayRefWithData( $Param{Result}->{hits}->{hits} ) ) {
        my $Hits   = $Param{Result}->{hits}->{hits};
        my @Fields = keys %{ $Param{Fields} };

        # when specified fields are filtered response
        # contains them inside "fields" key
        if (
            $Param{QueryData}->{Query}->{Body}->{_source}
            && $Param{QueryData}->{Query}->{Body}->{_source} eq 'false'
            )
        {
            # filter scalar/array fields by return type
            my @ScalarFields = grep { $Param{Fields}->{$_}->{ReturnType} !~ m{\AARRAY|HASH\z} } @Fields;
            my @ArrayFields  = grep { $Param{Fields}->{$_}->{ReturnType} eq 'ARRAY' } @Fields;

            for my $Hit ( @{$Hits} ) {
                my %Data;

                # get proper data for scalar/hash/arrays from response
                for my $Field (@ScalarFields) {
                    $Data{$Field} = $Hit->{fields}->{$Field}->[0];
                }

                for my $Field (@ArrayFields) {
                    $Data{$Field} = $Hit->{fields}->{$Field};
                }

                push @Objects, \%Data;
            }
        }

        # ES engine response stores objects inside "_source" key by default
        elsif ( IsHashRefWithData( $Hits->[0]->{_source} ) || $Hits->[0]->{inner_hits} ) {

            # check if there will be a need to look for child objects data
            if ( $Param{NestedFieldsGet} ) {
                for my $Hit ( @{$Hits} ) {
                    my $Data = $Hit->{_source};
                    if ( $Hit->{inner_hits} ) {

                        for my $ChildKey ( sort keys %{ $Hit->{inner_hits} } ) {
                            for my $ChildHit ( @{ $Hit->{inner_hits}->{$ChildKey}->{hits}->{hits} } ) {
                                if (
                                    IsHashRefWithData( $ChildHit->{_source} )
                                    || IsHashRefWithData( $ChildHit->{inner_hits} )
                                    )
                                {
                                    for my $DualNestedChildKey ( sort keys %{ $ChildHit->{inner_hits} } ) {
                                        $DualNestedChildKey =~ /$ChildKey\.(.*)/;
                                        my $DualNestedChildRealName = $1;
                                        for my $DualNestedChildHit (
                                            @{ $ChildHit->{inner_hits}->{$DualNestedChildKey}->{hits}->{hits} }
                                            )
                                        {
                                            if ( $DualNestedChildHit->{_source}->{Content} ) {
                                                $DualNestedChildHit->{_source}->{Content}
                                                    = decode_base64( $DualNestedChildHit->{_source}->{Content} );
                                            }

                                            push @{ $ChildHit->{_source}{$DualNestedChildRealName} },
                                                $DualNestedChildHit->{_source};
                                        }
                                    }
                                }

                                push @{ $Data->{$ChildKey} }, $ChildHit->{_source};
                            }
                        }
                    }
                    if ( IsHashRefWithData($Data) ) {
                        push @Objects, $Data;
                    }
                }
            }
            else {
                if (
                    IsArrayRefWithData( $Param{QueryData}->{Query}->{Body}->{_source} )
                    &&
                    grep { $_ eq 'Articles.Attachments.Content' } @{ $Param{QueryData}->{Query}->{Body}->{_source} }
                    )
                {
                    for my $Hit ( @{$Hits} ) {
                        my $Articles = $Hit->{_source}->{Articles};

                        if ( IsArrayRefWithData($Articles) ) {
                            for ( my $i = 0; $i < scalar @{$Articles}; $i++ ) {
                                my $Attachments = $Articles->[$i]->{Attachments};

                                if ( IsArrayRefWithData($Attachments) ) {
                                    for ( my $j = 0; $j < scalar @{$Attachments}; $j++ ) {
                                        my $Attachment = $Attachments->[$j];

                                        if ( $Attachment->{Content} ) {
                                            $Hit->{_source}->{Articles}->[$i]->{Attachments}->[$j]->{Content}
                                                = decode_base64( $Attachment->{Content} );
                                        }
                                    }
                                }
                            }
                        }
                        push @Objects, $Hit->{_source};
                    }
                }
                else {
                    for my $Hit ( @{$Hits} ) {
                        push @Objects, $Hit->{_source};
                    }
                }
            }
        }
    }
    elsif ( IsArrayRefWithData( $Param{Result}->{rows} ) ) {
        for ( my $j = 0; $j < scalar @{ $Param{Result}->{rows} }; $j++ ) {
            my %Data;
            for ( my $i = 0; $i < scalar @{ $Param{Result}->{columns} }; $i++ ) {
                $Data{ $Param{Result}->{columns}->[$i]->{name} } = $Param{Result}->{rows}->[$j]->[$i];
            }
            push @Objects, \%Data;
        }
    }

    return \@Objects;
}

1;
