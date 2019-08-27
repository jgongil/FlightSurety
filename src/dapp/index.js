
import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';


(async() => {

    let result = null;

    let contract = new Contract('localhost', () => {

        // Read Operational Status
        contract.isOperational((error, result) => {
            console.log(error,"Operational status of the contrac: " + result);
            display('Operational Status', 'Check if contract is operational', [ { label: 'Operational Status', error: error, value: result} ]);
        });

        // Reads All registered flights
        contract.getRegisteredFlights((error, result) => {

            console.log(result[0].length);

            let availableFlights = [];
            for (let i = 0; i < result[0].length; ++i) {
                        let iFlight = {
                                        flightName: result[0][i],
                                        timestamp: result[1][i],
                                        airline: result[2][i]
                                    };
                availableFlights.push(iFlight);
            }
            console.log(availableFlights);

            availableFlights.forEach((availableFlights, key) => {
                DOM.elid('flight-selection').appendChild(DOM.option({id: key}, availableFlights.flightName + " - " + availableFlights.timestamp));
            });
        });

        // Purchase submission
        DOM.elid('submit-purchase').addEventListener('click', () => {
            let flight = DOM.elid('flight-number').value;
            let timestamp = 123;
            let amount = DOM.elid('amount-paid').value;
            console.log("Buying Insurance for Flight: ", flight);
            contract.buy(flight,timestamp,amount, (error, result) => {
                display('Purchase', 'New Insurance', [ { label: 'Insurance', error: error, value: result.flight + ' ' + result.timestamp} ]);
            });
        })

        // User-submitted transaction
        DOM.elid('submit-oracle').addEventListener('click', () => {
            let flight = DOM.elid('flight-number').value;
            // Write transaction
            contract.fetchFlightStatus(flight, (error, result) => {
                display('Oracles', 'Trigger oracles', [ { label: 'Fetch Flight Status', error: error, value: result.flight + ' ' + result.timestamp} ]);
            });
        })
    
    });
    

})();


function display(title, description, results) {
    let displayDiv = DOM.elid("display-wrapper");
    let section = DOM.section();
    section.appendChild(DOM.h2(title));
    section.appendChild(DOM.h5(description));
    results.map((result) => {
        let row = section.appendChild(DOM.div({className:'row'}));
        row.appendChild(DOM.div({className: 'col-sm-4 field'}, result.label));
        row.appendChild(DOM.div({className: 'col-sm-8 field-value'}, result.error ? String(result.error) : String(result.value)));
        section.appendChild(row);
    })
    displayDiv.append(section);

}