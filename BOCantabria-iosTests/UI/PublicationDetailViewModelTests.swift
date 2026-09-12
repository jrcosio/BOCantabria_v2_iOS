//
//  PublicationDetailViewModelTests.swift
//
//  Tres cosas que esta pantalla tiene que hacer y que se rompen en silencio si no se prueban: que
//  **observe** la fila en vez de recibirla (FR-003), que distinga «ya no está» de «ha fallado»
//  (FR-004), y que el documento se pida **al mostrarse la pestaña** y no al abrir (FR-016).
//

import Foundation
import Testing
@testable import BOCantabria_ios

@Suite("Modelo de pantalla: detalle")
@MainActor
struct PublicationDetailViewModelTests {

    @Test("La publicación observada se publica en el estado, con su sección")
    func theObservedPublicationLandsInTheState() async {
        let publicacion = publication(externalKey: "boc:1", sectionCode: "2", subsectionCode: "2.2")
        let viewModel = make(single: [.success(publicacion)])

        await viewModel.onAppear()
        await until("la publicación llega al estado") { viewModel.state.publication != nil }

        #expect(viewModel.state.publication == publicacion)
        #expect(viewModel.state.section?.code == "2.2")
        #expect(!viewModel.state.isMissing)
    }

    @Test("Una corrección posterior se refleja SIN salir y volver a entrar")
    func aLaterCorrectionIsReflectedWithoutLeavingTheScreen() async {
        // FR-003. Es lo que se gana observando la fila en vez de recibir la publicación por la
        // ruta: si viajara como objeto, esto sería una foto del momento en que se tocó la tarjeta.
        let antes = publication(externalKey: "boc:1", title: "AYUNTAMIENTO: título truncado")
        let despues = publication(externalKey: "boc:1", title: "AYUNTAMIENTO: título completo")
        let viewModel = make(single: [.success(antes), .success(despues)])

        await viewModel.onAppear()
        await until("llega la corrección") { viewModel.state.publication?.title == despues.title }

        #expect(viewModel.state.publication?.title == despues.title)
    }

    @Test("Una publicación retirada NO es un error: es un desenlace previsto")
    func aRetiredPublicationIsNotAnError() async {
        let viewModel = make(single: [.success(nil)])

        await viewModel.onAppear()
        await until("se sabe que ya no está") { viewModel.state.isMissing }

        #expect(viewModel.state.isMissing)
        #expect(viewModel.state.publication == nil)
        // Y **no** se pinta como error del documento: eso tendría reintento, y reintentar no la trae.
        #expect(viewModel.state.document == .absent)
    }

    @Test("Un fallo de lectura SÍ es un error, y no se confunde con «ya no está»")
    func aReadFailureIsAnErrorAndNotAWithdrawal() async {
        let viewModel = make(single: [.failure(.storage)])

        await viewModel.onAppear()
        await until("llega el fallo de lectura") { viewModel.state.loadFailed }

        #expect(!viewModel.state.isMissing)
        // **Y NO se escribe en `document`**: hacerlo era una carrera con la observación del
        // documento, que lo pisaba un instante después. Lo destapó esta misma prueba.
        #expect(viewModel.state.document == .absent)
    }

    @Test("El documento se pide al MOSTRARSE la pestaña, no al abrir la pantalla")
    func theDocumentIsRequestedWhenTheTabIsShownAndNotWhenTheScreenOpens() async {
        // FR-016. Quien solo quería ojear un anuncio no tiene por qué gastar sus datos en él.
        let documents = FakeDocumentRepository()
        let viewModel = make(single: [.success(publication(externalKey: "boc:1"))], documents: documents)

        // Se abre en la pestaña del resumen: **nadie pide el documento**.
        viewModel.onSelectTab(.aiSummary)
        await viewModel.onAppear()
        await until("la publicación llega") { viewModel.state.publication != nil }
        #expect(documents.ensuredKeys.isEmpty, "Abrir el detalle no puede disparar la descarga")

        // Al mostrarse la pestaña del documento, sí.
        viewModel.onSelectTab(.document)
        await viewModel.onDocumentTabShown()
        #expect(documents.ensuredKeys == ["boc:1"])
    }

    @Test("Volver a mostrar la pestaña no vuelve a pedir el documento")
    func showingTheTabAgainDoesNotAskTwice() async {
        let documents = FakeDocumentRepository()
        let viewModel = make(single: [.success(publication(externalKey: "boc:1"))], documents: documents)
        viewModel.onSelectTab(.aiSummary)
        await viewModel.onAppear()
        await until("la publicación llega") { viewModel.state.publication != nil }

        viewModel.onSelectTab(.document)
        await viewModel.onDocumentTabShown()
        await viewModel.onDocumentTabShown()
        await viewModel.onDocumentTabShown()

        #expect(documents.ensuredKeys.count == 1)
    }

    @Test("El reintento sí vuelve a pedirlo: para eso está")
    func retryingDoesAskAgain() async {
        let documents = FakeDocumentRepository()
        let viewModel = make(single: [.success(publication(externalKey: "boc:1"))], documents: documents)
        await viewModel.onAppear()
        await until("la publicación llega") { viewModel.state.publication != nil }

        await viewModel.onRetryDocument()

        #expect(documents.ensuredKeys.count >= 2)
    }

    @Test("El estado del documento observado llega al estado de pantalla")
    func theObservedDocumentStatusReachesTheScreenState() async {
        let doc = officialDocument(externalKey: "boc:1")
        let viewModel = make(
            single: [.success(publication(externalKey: "boc:1"))],
            documents: FakeDocumentRepository(statuses: ["boc:1": [.available(doc)]])
        )

        await viewModel.onAppear()
        await until("llega el documento") { viewModel.state.document == .available(doc) }

        #expect(viewModel.state.document == .available(doc))
    }

    @Test("La pestaña seleccionada es un evento del modelo, no un estado de la vista")
    func theSelectedTabIsTheModelsBusiness() {
        let viewModel = make()
        #expect(viewModel.state.selectedTab == .document)
        viewModel.onSelectTab(.aiSummary)
        #expect(viewModel.state.selectedTab == .aiSummary)
    }

    // MARK: - Compartir

    @Test("Compartir pasa por preparando y acaba en un destino")
    func sharingGoesThroughPreparingAndEndsInATarget() async {
        let viewModel = make(
            single: [.success(publication(externalKey: "boc:439765"))],
            documents: FakeDocumentRepository(result: .success(officialDocument(externalKey: "boc:439765")))
        )
        await viewModel.onAppear()
        await until("la publicación llega") { viewModel.state.publication != nil }

        await viewModel.onShare()

        guard case .ready(.document(let compartido)) = viewModel.state.share else {
            Issue.record("Debería ofrecer el documento, y ofrece \(viewModel.state.share)")
            return
        }
        #expect(compartido.fileName == "boc-439765.pdf")
    }

    @Test("El evento de compartir se consume y vuelve a reposo")
    func theShareEventIsConsumed() async {
        let viewModel = make(
            single: [.success(publication())],
            documents: FakeDocumentRepository(result: .success(officialDocument()))
        )
        await viewModel.onAppear()
        await until("la publicación llega") { viewModel.state.publication != nil }
        await viewModel.onShare()

        viewModel.onShareConsumed()

        #expect(viewModel.state.share == .idle)
    }

    // MARK: - Ayudas


    private func make(
        single: [AppResult<Publication?>] = [.success(publication(externalKey: "boc:1"))],
        documents: FakeDocumentRepository = FakeDocumentRepository()
    ) -> PublicationDetailViewModel {
        let publications = FakePublicationRepository(single: single)
        return PublicationDetailViewModel(
            externalKey: "boc:1",
            observePublication: ObservePublicationUseCase(repository: publications),
            observeDocument: ObserveOfficialDocumentUseCase(repository: documents),
            openDocument: OpenOfficialDocumentUseCase(repository: documents),
            shareDocument: ShareOfficialDocumentUseCase(
                documents: documents, connectivity: FakeConnectivityRepository(online: true)
            ),
            analytics: NoOpAnalyticsTracker()
        )
    }
}
