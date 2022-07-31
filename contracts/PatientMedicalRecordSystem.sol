// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

//imports
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {DoctorType} from "./DoctorType.sol";
import {HospitalType} from "./HospitalType.sol";
import {PatientType} from "./PatientType.sol";

//errors
error PatientMedicalRecords__NotOwner();
error PatientMedicalRecords__NotDoctor();
error PatientMedicalRecords__NotApproved();

contract PatientMedicalRecordSystem is ReentrancyGuard {
    //Type Declarations
    struct ApprovedDoctor {
        address doctorAddress;
        uint256 timestampOfApproval;
    }

    //Storage Variables
    mapping(address => PatientType.Patient) private s_patients;
    mapping(address => DoctorType.Doctor) private s_doctors;
    mapping(address => HospitalType.Hospital) private s_hospitals;

    //patientAddress -> doctorAddress -> approvdTimestamp
    mapping(address => ApprovedDoctor) private s_approvedDoctor; //A patient can only approve one doctor at a time. Approving other doctor will override the previous approval. This is done for security purpose.

    address private immutable i_owner;

    //Events
    event DoctorApproved(address indexed doctorAddress, address indexed patientAddress);
    event DoctorRevoked(address indexed doctorAddress, address indexed patientAddress);
    event patientsDetailsModified(address indexed patientAddress, PatientType.Patient indexed patientDetails); //added or modified
    event doctorsDetailsModified(address indexed doctorAddress, DoctorType.Doctor indexed doctorDetails); //added or modified to the mapping
    event hospitalsDetailsModified(
        address indexed hospitalAddress,
        HospitalType.Hospital indexed hospitalDetails
    ); //added(mostly) or modified

    //modifiers
    modifier onlyOwner() {
        if (msg.sender != i_owner) {
            revert PatientMedicalRecords__NotOwner();
        }
        _;
    }

    modifier onlyDoctor() {
        if (s_doctors[msg.sender].doctorAddress != msg.sender) {
            revert PatientMedicalRecords__NotDoctor();
        }
        _;
    }

    modifier onlyApproved(address _patientAddress, address _doctorAddress) {
        if (s_approvedDoctor[_patientAddress].doctorAddress != _doctorAddress) {
            //if approve timestamp is == 0 (same as epoch time)
            revert PatientMedicalRecords__NotApproved();
        }
        _;
    }

    constructor() {
        i_owner = msg.sender;
    }

    //Functions

    //patients can themselves register to the system.
    function registerPatient(
        address _patientAddress,
        PatientType.Patient memory _patientDetails
    ) external {
        s_patients[_patientAddress] = _patientDetails;
        emit patientsDetailsModified(_patientAddress, _patientDetails);
    }

    //Adds the patient details (treatment details). This IPFS hash contains all the information about the treatment in json format pinned to pinata.
    function addPatientDetails(
        address _patientAddress,
        uint8 _category,
        string calldata _IpfsHash
    ) external onlyDoctor onlyApproved(_patientAddress, msg.sender) nonReentrant {
        PatientType.Patient memory patient = s_patients[_patientAddress];

        if (_category == 0) {
            s_patients[_patientAddress].vaccinationHash.push(_IpfsHash);
        } else if (_category == 1) {
            s_patients[_patientAddress].accidentHash.push(_IpfsHash);
        } else if (_category == 2) {
            s_patients[_patientAddress].chronicHash.push(_IpfsHash);
        } else if (_category == 3) {
            s_patients[_patientAddress].acuteHash.push(_IpfsHash);
        }
        s_patients[_patientAddress] = patient;
        //emitting the event.
        emit patientsDetailsModified(_patientAddress, s_patients[_patientAddress]);
    }

    //this will be done using script by the owner
    function addDoctorDetails(
        address _doctorAddress,
        DoctorType.Doctor memory _doctorDetails
    ) external onlyOwner nonReentrant {
        s_doctors[_doctorAddress] = _doctorDetails;
        // s_hospitalToDoctor[hospitalAddress][doctorAddress] = doctor;
        //emitting the event.
        emit doctorsDetailsModified(_doctorAddress, _doctorDetails);
    }

    //this will be done using script by the owner
    function addHospitalDetails(
        address _hospitalAddress,
        string calldata _name,
        string calldata _email,
        string calldata _phoneNumber
    ) external onlyOwner nonReentrant {
        HospitalType.Hospital memory hospital = s_hospitals[_hospitalAddress];
        hospital.name = _name;
        hospital.email = _email;
        hospital.phoneNumber = _phoneNumber;
        s_hospitals[_hospitalAddress] = hospital;
        //emitting the event.
        emit hospitalsDetailsModified(_hospitalAddress, hospital);
    }

    function approveDoctor(address _doctorAddress) external nonReentrant {
        s_approvedDoctor[msg.sender].timestampOfApproval = block.timestamp; //current timestamp
        emit DoctorApproved(_doctorAddress, msg.sender);
    }

    //revoking the approval of a doctor
    function revokeApproval(address _doctorAddress) external nonReentrant {
        s_approvedDoctor[msg.sender].doctorAddress = 0x0000000000000000000000000000000000000000; //timestamp 0 means that the doctor is not authorized.
        emit DoctorRevoked(_doctorAddress, msg.sender);
    }

    //view or pure functions
    //patient viewing his own records only
    function getMyDetails() external view returns (PatientType.Patient memory) {
        return s_patients[msg.sender];
    }

    //authorized doctor viewing patient's records
    function getPatientDetails(address _patientAddress)
        external
        view
        onlyDoctor
        onlyApproved(_patientAddress, msg.sender)
        returns (PatientType.Patient memory)
    {
        return s_patients[_patientAddress];
    }

    function getDoctorDetails(address _doctorAddress) external view returns (DoctorType.Doctor memory) {
        return s_doctors[_doctorAddress];
    }

    function getHospitalDetails(address _hospitalAddress) external view returns (HospitalType.Hospital memory) {
        return s_hospitals[_hospitalAddress];
    }

    //patients can check his approved doctor's list.
    function getApprovedDoctor() external view returns (ApprovedDoctor memory) {
        return s_approvedDoctor[msg.sender];
    }

    function getPatientRecordsByOwner(address _patientAddress)
        external
        view
        onlyOwner
        returns (PatientType.Patient memory)
    {
        return s_patients[_patientAddress];
    }

    function getOwner() external view returns (address) {
        return i_owner;
    }
}