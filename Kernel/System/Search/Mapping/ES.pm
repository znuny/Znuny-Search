# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Mapping::ES;

use strict;
use warnings;

use parent qw( Kernel::System::Search::Mapping );

use Kernel::System::VariableCheck qw(IsArrayRefWithData);

our @ObjectDependencies = (
    'Kernel::System::Log',
);

=head1 NAME

Kernel::System::Search::Mapping::ES - TO-DO

=head1 DESCRIPTION

TO-DO

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $MappingESObject = $Kernel::OM->Get('Kernel::System::Search::Mapping::ES');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=head2 ResultFormat()

globally formats result of specified engine

    my $FormatResult = $MappingESObject->ResultFormat(
        Result      => $ResponseResult,
        Config      => $Config,
        IndexName   => $IndexName,
    );

=cut

sub ResultFormat {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(Result Config IndexName)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Missing param: $Needed",
        );
        return;
    }

    my $IndexName = $Param{IndexName};
    my $Result    = $Param{Result};

    return {
        Reason => $Result->{reason},
        Status => $Result->{status},
        Type   => $Result->{type}
    } if $Result->{status};

    my $GloballyFormattedObjData = $Self->ResponseDataFormat(
        Hits => $Result->{hits}->{hits}
    );

    return {
        "$IndexName" => {
            ObjectData => $GloballyFormattedObjData,
            EngineData => {
                Shards       => $Result->{_shards},
                ResponseTime => $Result->{took},
            }
        }
    };
}

=head2 Search()

process query data to structure that will be used to execute query

    my $Result = $MappingESObject->Search(
        QueryParams   => $QueryParams,
    );

=cut

sub Search {
    my ( $Self, %Param ) = @_;

    # Empty query template.
    my %Query = (
        query => {
            bool => {}
        }
    );

    for my $Param ( sort keys %{ $Param{QueryParams} } ) {

        my $Must = {
            match => {
                $Param => {
                    query => $Param{QueryParams}->{$Param}
                }
            }
        };

        push @{ $Query{query}{bool}{must} }, $Must;
    }

    # $Query{query} = { # E.Q. initial Query
    #     query=>{
    #         bool => {
    #             must => [
    #                 {
    #                     match => {
    #                         Owner =>{
    #                             query => "Kamil Furtek"
    #                         }
    #                     }
    #                 },
    #                 {
    #                     match => {
    #                         Responsible =>{
    #                             query => "Kamil Furtek"
    #                         }
    #                     }
    #                 }
    #             ]
    #         }
    #     }
    # }

    return \%Query;
}

=head2 ObjectIndexAdd()

process query data to structure that will be used to execute query

    my $Result = $MappingESObject->ObjectIndexAdd(
        Config   => $Config,
        Index    => $Index,
        ObjectID => $ObjectID,
        Body     => $Body,
    );

=cut

sub ObjectIndexAdd {
    my ( $Type, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(Config Index ObjectID Body)) {

        next NEEDED if defined $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    my $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::$Param{Index}");

    my $Result = {
        Index => $IndexObject->{Config}->{IndexRealName},
        Body  => $Param{Body}
    };

    return $Result;
}

=head2 ObjectIndexUpdate()

process query data to structure that will be used to execute query

    my $Result = $MappingESObject->ObjectIndexUpdate(
        Config   => $Config,
        Index    => $Index,
        ObjectID => $ObjectID,
        Body     => $Body,
    );

=cut

sub ObjectIndexUpdate {
    my ( $Type, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(Config Index ObjectID Body)) {

        next NEEDED if defined $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    my $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::$Param{Index}");

    my $Result = {
        Index => $IndexObject->{Config}->{IndexRealName},
        Body  => $Param{Body}
    };

    return $Result;
}

=head2 ObjectIndexGet()

process query data to structure that will be used to execute query

=cut

sub ObjectIndexGet {
    my ( $Type, %Param ) = @_;

    return 1;
}

=head2 ObjectIndexRemove()

process query data to structure that will be used to execute query

    my $Result = $MappingESObject->ObjectIndexRemove(
        Config   => $Config,
        Index    => $Index,
        ObjectID => $ObjectID,
    );

=cut

sub ObjectIndexRemove {
    my ( $Type, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(Config Index ObjectID)) {

        next NEEDED if defined $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    my $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::$Param{Index}");

    my $Result = {
        Index => $IndexObject->{Config}->{IndexRealName},
    };

    return $Result;    # Need to use perform_request()
}

=head2 ResponseDataFormat()

globally formats response data from engine

=cut

sub ResponseDataFormat {
    my ( $Self, %Param ) = @_;

    return [] if !IsArrayRefWithData( $Param{Hits} );

    my $Hits = $Param{Hits};

    my @Objects;

    # ES engine response stores objects inside _source key
    for my $Hit ( @{$Hits} ) {
        push @Objects, $Hit->{_source};
    }

    return \@Objects;
}

=head2 IndexClear()

returns query for engine to clear whole index from objects

    my $Result = $MappingESObject->IndexClear(
        Index => $Index,
    );

=cut

sub IndexClear {
    my ( $Self, %Param ) = @_;

    my $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::$Param{Index}");

    my $Query = {
        Index => $IndexObject->{Config}->{IndexRealName},
        Body  => {
            query => {
                match_all => {}
            }
        }
    };

    return $Query;
}

1;
