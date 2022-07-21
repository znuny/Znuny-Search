# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsHashRefWithData IsArrayRefWithData);

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Search::Object',
    'Kernel::System::Main',
    'Kernel::Config',
);

=head1 NAME

Kernel::System::Search - Search backend functions

=head1 DESCRIPTION

TO-DO

=head1 PUBLIC INTERFACE

=head2 new()

TO-DO

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    $Self->{Config} = $Self->ConfigGet();

    # Check if ElasticSearch feature is enabled.
    if ( !$Self->{Config}->{Enabled} ) {
        $Self->{Error} = 1;
    }

    my $ModulesCheckOk;

    # Check if there is choosen active engine of the search.
    if ( !$Self->{Config}->{ActiveEngine} && !$Self->{Error} ) {
        $Self->{Error} = 1;
        $LogObject->Log(
            Priority => 'error',
            Message  => "Search configuration does not specify a valid active engine!",
        );
    }
    else {
        $ModulesCheckOk = $Self->BaseModulesCheck(
            Config => $Self->{Config},
        );
    }

    if ( !$ModulesCheckOk ) {
        $Self->{Error} = 1;
    }

    # If there were no errors before, try connecting.
    my $ConnectObject;
    $ConnectObject = $Self->Connect(
        Config => $Self->{Config},
    ) if !$Self->{Error};

    if ( !$ConnectObject || $ConnectObject->{Error} ) {
        $Self->{Error} = 1;
    }
    else {
        $Self->{ConnectObject} = $ConnectObject;
    }

    return $Self;
}

=head2 Search()

search for specified index

    $TicketSearch = $SearchObject->Search(
        Objects => ["Ticket"],
        QueryParams => {
            TicketID => 1,
        }
        ResultType => 'ARRAY|HASH|COUNT' (optional, default: 'ARRAY')
    );

=cut

sub Search {
    my ( $Self, %Param ) = @_;

    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search::Object');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    NEEDED:
    for my $Needed (qw(Objects QueryParams)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Missing param: $Needed",
        );
        return;
    }

    # If there was an critical error, fallback all of the objects with given search parameters.
    if ( $Self->{Error} ) {
        my $Response = $SearchObject->Fallback(%Param);
        return $Response;
    }

    my $QueryData = $SearchObject->QueryPrepare(
        %Param,
        Operation     => "Search",
        Config        => $Self->{Config},
        MappingObject => $Self->{MappingObject},
    );

    my $Fallback;
    my @ValidQueries = ();

    if ( !defined $QueryData ) {
        $Fallback = 1;
    }
    elsif ( IsArrayRefWithData( $QueryData->{Queries} ) ) {
        if ( grep { $_->{Fallback}->{Enable} } @{ $QueryData->{Queries} } ) {
            $Fallback = 1;
        }
        else {
            @ValidQueries = grep { !$_->{Error} } @{ $QueryData->{Queries} };
        }
    }
    if ($Fallback) {
        return $SearchObject->Fallback(%Param);
    }

    my %Result;
    my $RegisteredIndexes = $Self->{Config}->{RegisteredIndexes};

    QUERY:
    for my $Query (@ValidQueries) {
        my $Index = $RegisteredIndexes->{ $Query->{Object} };

        my $ResultQuery = $Self->{EngineObject}->QueryExecute(
            Query         => $Query->{Query},
            Index         => $Index,
            Operation     => 'Search',
            ConnectObject => $Self->{ConnectObject},
            Config        => $Self->{Config},
        );

        next QUERY if !$ResultQuery;

        if ( $ResultQuery->{Fallback}->{Enable} ) {
            return $SearchObject->Fallback(%Param);
        }
        elsif (
            $ResultQuery->{Error}
            )
        {
            next QUERY;
        }

        my $FormattedResult = $Self->_ResultFormat(
            Result     => $ResultQuery,
            Config     => $Self->{Config},
            IndexName  => $Query->{Object},
            Operation  => "Search",
            ResultType => $Param{ResultType} // ''
        );

        if ( defined $FormattedResult ) {
            %Result = ( %Result, %{$FormattedResult} );
        }
    }

    return \%Result;
}

=head2 ObjectIndexAdd()

add object for specified index

    my $Success = $SearchObject->ObjectIndexAdd(
        Index => "Ticket",
        ObjectID => 1,
    );

=cut

sub ObjectIndexAdd {
    my ( $Self, %Param ) = @_;

    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search::Object');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    NEEDED:
    for my $Needed (qw(Index ObjectID)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Missing param: $Needed",
        );

        return;
    }

    if ( $Self->{Error} ) {
        return;
    }

    my $QueryData = $SearchObject->QueryPrepare(
        %Param,
        Operation     => "ObjectIndexAdd",
        Config        => $Self->{Config},
        MappingObject => $Self->{MappingObject},
    );

    if ( !defined $QueryData->{Query} ) {
        return;
    }

    my $ResultQuery = $Self->{EngineObject}->QueryExecute(
        %Param,
        Operation     => "ObjectIndexAdd",
        Query         => $QueryData->{Query},
        ConnectObject => $Self->{ConnectObject},
        Config        => $Self->{Config},
    );

    if ( $ResultQuery->{Error} )
    {
        return;
    }

    return 1;
}

=head2 ObjectIndexUpdate()

update object for specified index

    my $Success = $SearchObject->ObjectIndexUpdate(
        Index => "Ticket",
        ObjectID => 1,
    );

=cut

sub ObjectIndexUpdate {
    my ( $Self, %Param ) = @_;

    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search::Object');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    NEEDED:
    for my $Needed (qw(Index ObjectID)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Missing param: $Needed",
        );
    }

    if ( $Self->{Error} ) {
        return;
    }

    my $QueryData = $SearchObject->QueryPrepare(
        %Param,
        Operation     => "ObjectIndexUpdate",
        Config        => $Self->{Config},
        MappingObject => $Self->{MappingObject},
    );

    if ( !defined $QueryData->{Query} ) {
        return;
    }

    my $ResultQuery = $Self->{EngineObject}->QueryExecute(
        %Param,
        Query         => $QueryData->{Query},
        Operation     => "ObjectIndexUpdate",
        ConnectObject => $Self->{ConnectObject},
        Config        => $Self->{Config},
    );

    if ( $ResultQuery->{Error} )
    {
        return;
    }

    return 1;
}

=head2 ObjectIndexGet()

get object for specified index

=cut

sub ObjectIndexGet {
    my ( $Self, %Param ) = @_;

    return 1;
}

=head2 ObjectIndexRemove()

remove object for specified index

    my $Success = $SearchObject->ObjectIndexRemove(
        Index => "Ticket",
        ObjectID => 1,
    );

=cut

sub ObjectIndexRemove {
    my ( $Self, %Param ) = @_;

    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search::Object');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    NEEDED:
    for my $Needed (qw(Index ObjectID)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Missing param: $Needed",
        );
    }

    if ( $Self->{Error} ) {
        return;
    }

    my $QueryData = $SearchObject->QueryPrepare(
        %Param,
        Operation     => "ObjectIndexRemove",
        Config        => $Self->{Config},
        MappingObject => $Self->{MappingObject},
    );

    if ( !defined $QueryData->{Query} ) {
        return;
    }

    my $ResultQuery = $Self->{EngineObject}->QueryExecute(
        %Param,
        Query         => $QueryData->{Query},
        Operation     => "ObjectIndexRemove",
        ConnectObject => $Self->{ConnectObject},
        Config        => $Self->{Config},
    );

    if ( $ResultQuery->{Error} )
    {
        return;
    }

    return 1;
}

=head2 Connect()

connect for active search engine

    my $ConnectObject = $SearchObject->Connect(
        Config => $Self->{Config},
    );

=cut

sub Connect {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    if ( !IsHashRefWithData( $Param{Config} ) ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Need Config!"
        );
        return;
    }

    return if !$Self->{EngineObject}->can('Connect');
    my $ConnectObject = $Self->{EngineObject}->Connect(%Param);

    return $ConnectObject;
}

=head2 Disconnect()

TO-DO

=cut

sub Disconnect {
    my ( $Self, %Param ) = @_;

    return 1;
}

=head2 IndexAdd()

TO-DO

=cut

sub IndexAdd {
    my ( $Self, %Param ) = @_;

    return 1;
}

=head2 IndexDrop()

TO-DO

=cut

sub IndexDrop {
    my ( $Self, %Param ) = @_;

    return 1;
}

=head2 ConfigGet()

get basic config for search

    $Config = $SearchObject->ConfigGet();

=cut

sub ConfigGet {
    my ( $Self, %Param ) = @_;

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    my $SearchLoaderConfig = $ConfigObject->Get("Loader::Search");
    my @SearchConfigKeys   = sort keys %{$SearchLoaderConfig};

    my %SearchLoader = ();
    for my $Key (@SearchConfigKeys) {
        for my $InnerKey ( sort keys %{ $SearchLoaderConfig->{$Key} } ) {
            $SearchLoader{$InnerKey} = $SearchLoaderConfig->{$Key}->{$InnerKey};
        }
    }

    my %Config = (
        ActiveEngine      => "ES",    # MOCK-UP
        Enabled           => 1,       # MOCK-UP
        RegisteredIndexes => {        # key: friendly name for calls, value: name in search engine structure
            %SearchLoader
        }
    );

    return \%Config;
}

=head2 BaseModulesCheck()

check for base modules validity

    my $ModulesCheckOk = $SearchObject->BaseModulesCheck(
        Config => $Self->{Config},
    );

=cut

sub BaseModulesCheck {
    my ( $Self, %Param ) = @_;

    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');
    my $MainObject = $Kernel::OM->Get('Kernel::System::Main');

    return if !$Param{Config}->{ActiveEngine};

    # define base modules
    my %Modules = (
        "Mapping" => "Kernel::System::Search::Mapping::$Param{Config}->{ActiveEngine}",
        "Engine"  => "Kernel::System::Search::Engine::$Param{Config}->{ActiveEngine}",
    );

    # check if base modules exists and add them to $Self
    for my $Module ( sort keys %Modules ) {
        my $Location = $Modules{$Module};
        my $Loaded   = $MainObject->Require(
            $Location,
            Silent => 0,
        );
        if ( !$Loaded ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Module $Location is not valid!"
            );
            return;
        }
        else {
            $Self->{ $Module . "Object" } = $Kernel::OM->Get($Location);
        }
    }

    return 1;
}

=head2 _ResultFormat()

format response data globally, then index specifically

    my $ModulesCheckOk = $SearchObject->BaseModulesCheck(
        Config => $Self->{Config},
    );

=cut

sub _ResultFormat {
    my ( $Self, %Param ) = @_;

    my $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::$Param{IndexName}");
    my $LogObject   = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(Operation Result Config IndexName)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Missing param: $Needed",
        );
        return;
    }

    my %OperationMapping = (
        Search            => 'SearchFormat',
        ObjectIndexAdd    => 'ObjectIndexAddFormat',
        ObjectIndexGet    => 'ObjectIndexGetFormat',
        ObjectIndexRemove => 'ObjectIndexRemoveFormat',
    );

    # Globaly standarize format to understandable by search engine.
    my $GloballyFormattedResult = $Self->{MappingObject}->ResultFormat(
        Result    => $Param{Result},
        Config    => $Param{Config},
        IndexName => $Param{IndexName},
    );

    my $OperationFormatFunction = $OperationMapping{ $Param{Operation} };
    my $IndexFormattedResult    = $IndexObject->$OperationFormatFunction(
        GloballyFormattedResult => $GloballyFormattedResult,
        %Param
    );

    return $IndexFormattedResult;
}

1;
