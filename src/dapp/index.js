
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

        // Oracle fetch flight status
        DOM.elid('submit-oracle').addEventListener('click', () => {
            let flightDetails = DOM.elid('flight-status-selection').value;
            flightDetails = flightDetails.split(",");
            let flightName = flightDetails[0];
            let flightTimestamp = flightDetails[1];
            let flightAirline = flightDetails[2];
            // Write transaction
            contract.fetchFlightStatus(flightAirline,flightName,flightTimestamp, (error, result) => {
                display('Oracles', 'Trigger oracles', [ { label: 'Fetch Flight Status', error: error, value: result.flight + ' ' + result.timestamp} ]);
            });
        })

        // Reads all registered flights to make them available in the dropdow list
        contract.getRegisteredFlights((error, result) => {

            console.log("Number of flights registered: ",result[0].length);

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
            populateForm(availableFlights);
        });

        // Purchase submission
        DOM.elid('submit-purchase').addEventListener('click', () => {
            let flightDetails = DOM.elid('flight-selection').value;
            let amount = DOM.elid('amount-paid').value;
            flightDetails = flightDetails.split(",");
            let flightName = flightDetails[0];
            let flightTimestamp = flightDetails[1];
            let flightAirline = flightDetails[2];
            console.log("Buying Insurance from airline " + flightAirline + " for flight: " + flightName + " with timestamp: " + flightTimestamp + " with value " + amount);
            contract.buy(flightAirline, flightName, flightTimestamp, amount, (error, result) => {
                display('Purchase', 'New Insurance', [ { label: 'New insurance successfully purchased: ', error: error, value: result.flight + ' ' + result.timestamp  + ' ' + result.airline} ]);
            });
        });

/*         // Listening to events
        contract.eventsListener((error, result) => {
            console.log(error,"Operational status of the contrac: " + result);
            display('Events', 'Event Received', [ { label: 'Event', error: error, value: result} ]);
        }); */

        

    });
    

})();



// Populates the dropdown list of available flights
function populateForm(availableFlights) {
    let selectf = DOM.elid("flight-selection");
    availableFlights.forEach((availableFlight, key) => {
        console.log(availableFlight, key);
       let optionf = DOM.option();
        DOM.appendText(optionf,Object.values(availableFlight));
        selectf.appendChild(optionf);  
    });
    let selects = DOM.elid("flight-status-selection");
    availableFlights.forEach((availableFlight, key) => {
        console.log(availableFlight, key);
       let options = DOM.option();
        DOM.appendText(options,Object.values(availableFlight));
        selects.appendChild(options);
    });
}

function display(title, description, results) {
    let displayDiv = DOM.elid("display-wrapper"); // main container
    let section = DOM.section(); // section
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



