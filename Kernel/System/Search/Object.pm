# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Main',
);

=head1 NAME

Kernel::System::Search::Object - Functions index related

=head1 DESCRIPTION

TO-DO

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search::Object');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=head2 Fallback()

fallback from using advanced search

    my $Result = $SearchObject->Fallback(
        IndexName    => $IndexName,
        QueryParams  => $QueryParams
    );

=cut

sub Fallback {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(IndexName QueryParams)) {

        next NEEDED if defined $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    my $Result;
    my $IndexName = $Param{IndexName};

    my $Loaded = $Self->_LoadModule(
        Module => "Kernel::System::Search::Object::${IndexName}",
    );

    # TODO support for not loaded module
    return if !$Loaded;
    my $SearchIndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::${IndexName}");

    $Result->{$IndexName} = $SearchIndexObject->Fallback(
        QueryParams => $Param{QueryParams}
    );

    return $Result;
}

=head2 QueryPrepare()

prepare query for active engine with specified operation

    my $Result = $SearchObject->QueryPrepare(
        Config          => $Config,
        MappingObject   => $MappingObject,
        Operation       => $Operation,
    );

=cut

sub QueryPrepare {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    for my $Name (qw( Operation MappingObject Config )) {
        if ( !$Param{$Name} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Name!"
            );
            return;
        }
    }

    my $FunctionName = '_QueryPrepare' . $Param{Operation};

    my $Result = $Self->$FunctionName(
        %Param
    );

    return $Result;
}

=head2 _QueryPrepareSearch()

prepares query for active engine with specified object "Search" operation

    my $Result = $SearchObject->_QueryPrepareSearch(
        MappingObject     => $MappingObject,
        Objects           => $Objects,
        QueryParams       => $QueryParams,
        Config            => $Config
    );

=cut

sub _QueryPrepareSearch {
    my ( $Self, %Param ) = @_;

    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');
    my $MainObject = $Kernel::OM->Get('Kernel::System::Main');

    my $Result = {};
    my @Queries;

    for my $Name (qw( QueryParams Objects MappingObject Config )) {
        if ( !$Param{$Name} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Name!"
            );
            return;
        }
    }

    OBJECT:
    for my $Index ( @{ $Param{Objects} } ) {

        my $Loaded = $Self->_LoadModule(
            Module => "Kernel::System::Search::Object::Query::${Index}"
        );

        # TODO support for not loaded module
        next OBJECT if !$Loaded;

        my $IndexQueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query::${Index}");

        # my $Data = { # Response example
        #     Error    => 0,
        #     Fallback => {
        #         Enable => 1
        #     },
        #     Query => 'Queries 1'
        # };
        my $Data = $IndexQueryObject->Search(
            QueryParams   => $Param{QueryParams},
            MappingObject => $Param{MappingObject},
            Config        => $Param{Config},
            Object        => $Index,
        );

        $Data->{Object} = $Index;
        push @Queries, $Data;
    }

    $Result->{Queries} = \@Queries;

    return $Result;
}

=head2 _QueryPrepareObjectIndexAdd()

prepares query for active engine with specified object "Add" operation

    my $Result = $SearchObject->_QueryPrepareObjectIndexAdd(
        MappingObject   => $MappingObject,
        ObjectID        => $ObjectID,
        Index           => $Index,
        Config          => $Config
    );

=cut

sub _QueryPrepareObjectIndexAdd {
    my ( $Self, %Param ) = @_;

    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');
    my $MainObject = $Kernel::OM->Get('Kernel::System::Main');

    for my $Name (qw( Index ObjectID MappingObject Config )) {
        if ( !$Param{$Name} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Name!"
            );
            return;
        }
    }

    my $Index = $Param{Index};

    my $Loaded = $Self->_LoadModule(
        Module => "Kernel::System::Search::Object::Query::${Index}",
    );

    # TODO support for not loaded module
    return if !$Loaded;

    my $IndexQueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query::${Index}");

    my $Data = $IndexQueryObject->ObjectIndexAdd(
        %Param,
        MappingObject => $Param{MappingObject},
        Config        => $Param{Config},
        ObjectID      => $Param{ObjectID},
    );

    return $Data;
}

=head2 _QueryPrepareObjectIndexUpdate()

prepares query for active engine with specified object "Update" operation

    my $Result = $SearchObject->_QueryPrepareObjectIndexUpdate(
        MappingObject   => $MappingObject,
        ObjectID        => $ObjectID,
        Index           => $Index,
        Config          => $Config
    );

=cut

sub _QueryPrepareObjectIndexUpdate {
    my ( $Self, %Param ) = @_;

    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');
    my $MainObject = $Kernel::OM->Get('Kernel::System::Main');

    for my $Name (qw( Index ObjectID MappingObject Config )) {
        if ( !$Param{$Name} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Name!"
            );
            return;
        }
    }

    my $Index = $Param{Index};

    my $Loaded = $Self->_LoadModule(
        Module => "Kernel::System::Search::Object::Query::${Index}",
    );

    # TODO support for not loaded module
    return if !$Loaded;

    my $IndexQueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query::$Param{Index}");

    my $Data = $IndexQueryObject->ObjectIndexUpdate(
        %Param,
        MappingObject => $Param{MappingObject},
        Config        => $Param{Config},
        ObjectID      => $Param{ObjectID},
    );

    return $Data;
}

=head2 _QueryPrepareObjectIndexGet()

TO-DO

=cut

sub _QueryPrepareObjectIndexGet {
    my ( $Self, %Param ) = @_;

    return 1;
}

=head2 _QueryPrepareObjectIndexRemove()

prepare query for index object removal

    my $Query = $SearchObject->_QueryPrepareObjectIndexRemove(
        Index         => 'Ticket',
        ObjectID      => 1,
        MappingObject => $MappingObject,
        Config        => $Config
    );

=cut

sub _QueryPrepareObjectIndexRemove {
    my ( $Self, %Param ) = @_;

    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');
    my $MainObject = $Kernel::OM->Get('Kernel::System::Main');

    for my $Name (qw( Index ObjectID MappingObject Config )) {
        if ( !$Param{$Name} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Name!"
            );
            return;
        }
    }

    my $Index = $Param{Index};

    my $Loaded = $Self->_LoadModule(
        Module => "Kernel::System::Search::Object::Query::${Index}",
    );

    # TODO support for not loaded module
    return if !$Loaded;

    my $IndexQueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query::$Param{Index}");

    my $Data = $IndexQueryObject->ObjectIndexRemove(
        %Param,
        MappingObject => $Param{MappingObject},
        Config        => $Param{Config},
        ObjectID      => $Param{ObjectID},
    );

    return $Data;
}

=head2 _LoadModule()

loads/check module

    my $Loaded = $SearchObject->_LoadModule(
        Module => 'Kernel::System::Search::Object::Query::SomeModuleName',
    );

=cut

sub _LoadModule {
    my ( $Self, %Param ) = @_;

    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');
    my $MainObject = $Kernel::OM->Get('Kernel::System::Main');

    NEEDED:
    for my $Needed (qw(Module)) {

        next NEEDED if defined $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    my $Module = $Param{Module};

    if ( !$Self->{LoadedModules}->{$Module} ) {
        my $Loaded = $MainObject->Require(
            $Module,
            Silent => 0,
        );
        if ( !$Loaded ) {

            # TO-DO support not loaded object
            # for now ignore them
            return;
        }
        else {
            $Self->{LoadedModules}->{$Module} = $Loaded;
        }
    }
    return 1;
}

=head2 _QueryPrepareIndexClear()

prepares query for index clear operation

    my $Result = $SearchObject->_QueryPrepareIndexClear(
        MappingObject   => $MappingObject,
        Index           => $Index,
        Config          => $Config
    );

=cut

sub _QueryPrepareIndexClear {
    my ( $Self, %Param ) = @_;

    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');
    my $MainObject = $Kernel::OM->Get('Kernel::System::Main');

    for my $Name (qw( Index MappingObject Config )) {
        if ( !$Param{$Name} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Name!"
            );
            return;
        }
    }

    my $Index = $Param{Index};

    my $Loaded = $Self->_LoadModule(
        Module => "Kernel::System::Search::Object::Query::${Index}",
    );

    return if !$Loaded;

    my $IndexQueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query::$Param{Index}");

    my $Data = $IndexQueryObject->IndexClear(
        %Param,
        MappingObject => $Param{MappingObject},
        Config        => $Param{Config},
    );

    return $Data;
}

1;
