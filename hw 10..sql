-- Створення бази даних
CREATE DATABASE BarberShop;
GO

USE BarberShop;
GO

-- Таблиця для барберів + заборона додавати барберів молодше 21 року
CREATE TABLE Barbers (
    BarberID INT IDENTITY PRIMARY KEY,
    FullName NVARCHAR(100) NOT NULL,
    Gender NVARCHAR(10) CHECK (Gender IN ('Male', 'Female')),
    PhoneNumber NVARCHAR(20),
    Email NVARCHAR(100),
    BirthDate DATE NOT NULL,
    HireDate DATE NOT NULL,
    Position NVARCHAR(20) CHECK (Position IN ('Chief Barber', 'Senior Barber', 'Junior Barber')),
	CONSTRAINT CK_Barber_Age CHECK (DATEDIFF(YEAR, BirthDate, GETDATE()) >= 21)
);

-- Таблиця для послуг
CREATE TABLE Services (
    ServiceID INT IDENTITY PRIMARY KEY,
    ServiceName NVARCHAR(100) NOT NULL,
    Price DECIMAL(10, 2) NOT NULL,
    DurationMinutes INT NOT NULL
);

-- Зв'язок барбера з послугами
CREATE TABLE BarberServices (
    BarberServiceID INT IDENTITY PRIMARY KEY,
    BarberID INT NOT NULL FOREIGN KEY REFERENCES Barbers(BarberID),
    ServiceID INT NOT NULL FOREIGN KEY REFERENCES Services(ServiceID)
);

-- Таблиця для клієнтів
CREATE TABLE Clients (
    ClientID INT IDENTITY PRIMARY KEY,
    FullName NVARCHAR(100) NOT NULL,
    PhoneNumber NVARCHAR(20),
    Email NVARCHAR(100)
);

-- Розклад барберів
CREATE TABLE BarberSchedule (
    ScheduleID INT IDENTITY PRIMARY KEY,
    BarberID INT NOT NULL FOREIGN KEY REFERENCES Barbers(BarberID),
    AvailableDate DATE NOT NULL,
    StartTime TIME NOT NULL,
    EndTime TIME NOT NULL
);

-- Таблиця записів
CREATE TABLE Appointments (
    AppointmentID INT IDENTITY PRIMARY KEY,
    BarberID INT NOT NULL FOREIGN KEY REFERENCES Barbers(BarberID),
    ClientID INT NOT NULL FOREIGN KEY REFERENCES Clients(ClientID),
    ServiceID INT NOT NULL FOREIGN KEY REFERENCES Services(ServiceID),
    AppointmentDate DATE NOT NULL,
    AppointmentTime TIME NOT NULL,
    TotalPrice DECIMAL(10, 2) NOT NULL,
    Rating INT CHECK (Rating BETWEEN 1 AND 5),
    Feedback NVARCHAR(MAX)
);

-- Заповнення таблиці барберів
INSERT INTO Barbers (FullName, Gender, PhoneNumber, Email, BirthDate, HireDate, Position)
VALUES
('John Smith', 'Male', '123456789', 'john.smith@example.com', '1985-06-15', '2010-01-01', 'Chief Barber'),
('Emily Johnson', 'Female', '987654321', 'emily.johnson@example.com', '1990-09-10', '2015-05-01', 'Senior Barber'),
('Mike Brown', 'Male', '555123456', 'mike.brown@example.com', '1995-12-20', '2020-03-15', 'Junior Barber');

-- Заповнення таблиці послуг
INSERT INTO Services (ServiceName, Price, DurationMinutes)
VALUES
('Haircut', 20.00, 30),
('Beard Trim', 15.00, 20),
('Shave', 25.00, 40);

-- Зв'язок барберів із послугами
INSERT INTO BarberServices (BarberID, ServiceID)
VALUES
(1, 1), (1, 2), (1, 3),
(2, 1), (2, 3),
(3, 1), (3, 2);

-- Заповнення клієнтів
INSERT INTO Clients (FullName, PhoneNumber, Email)
VALUES
('Alice Doe', '123123123', 'alice.doe@example.com'),
('Bob White', '456456456', 'bob.white@example.com');

-- Розклад барберів
INSERT INTO BarberSchedule (BarberID, AvailableDate, StartTime, EndTime)
VALUES
(1, '2024-12-01', '09:00', '17:00'),
(2, '2024-12-01', '10:00', '18:00'),
(3, '2024-12-01', '11:00', '19:00');

-- Запис на послуги
INSERT INTO Appointments (BarberID, ClientID, ServiceID, AppointmentDate, AppointmentTime, TotalPrice, Rating, Feedback)
VALUES
(1, 1, 1, '2024-12-01', '09:30', 20.00, 5, 'Great haircut!'),
(2, 2, 3, '2024-12-01', '10:30', 25.00, 4, 'Nice shave.');


-- Повернути ПІБ всіх барберів салону
SELECT FullName FROM Barbers;

-- Повернути інформацію про всіх синьйор-барберів
SELECT * FROM Barbers WHERE Position = 'Senior Barber';

-- Повернути інформацію про всіх барберів, які можуть надати послугу традиційного гоління бороди
SELECT DISTINCT b.*
FROM Barbers b
JOIN BarberServices bs ON b.BarberID = bs.BarberID
JOIN Services s ON bs.ServiceID = s.ServiceID
WHERE s.ServiceName = 'Shave';

-- Повернути інформацію про всіх барберів, які працюють понад зазначену кількість років
CREATE PROCEDURE BarbersByExperience (@Years INT)
AS
BEGIN
    SELECT * FROM Barbers
    WHERE DATEDIFF(YEAR, HireDate, GETDATE()) >= @Years;
END;
GO

EXEC BarbersByExperience @Years = 5;
-- Повернути кількість синьйор та джуніор барберів
SELECT 
    SUM(CASE WHEN Position = 'Senior Barber' THEN 1 ELSE 0 END) AS SeniorBarbersCount,
    SUM(CASE WHEN Position = 'Junior Barber' THEN 1 ELSE 0 END) AS JuniorBarbersCount
FROM Barbers;

--Повернути інформацію про постійних клієнтів
CREATE PROCEDURE GetFrequentClients (@VisitCount INT)
AS
BEGIN
    SELECT 
        c.ClientID,
        c.FullName,
        c.PhoneNumber,
        c.Email,
        COUNT(a.AppointmentID) AS TotalVisits
    FROM Clients c
    JOIN Appointments a ON c.ClientID = a.ClientID
    GROUP BY c.ClientID, c.FullName, c.PhoneNumber, c.Email
    HAVING COUNT(a.AppointmentID) >= @VisitCount;
END;
GO

-- Виконання процедури
EXEC GetFrequentClients @VisitCount = 2;


-- Заборонити видалення чиф-барбера без нового
CREATE TRIGGER PreventChiefBarberDeletion
ON Barbers
INSTEAD OF DELETE
AS
BEGIN
    IF EXISTS (SELECT * FROM deleted WHERE Position = 'Chief Barber')
    BEGIN
        IF (SELECT COUNT(*) FROM Barbers WHERE Position = 'Chief Barber') = 1
        BEGIN
            RAISERROR ('Cannot delete the only Chief Barber!', 16, 1);
            ROLLBACK;
            RETURN;
        END
    END
    DELETE FROM Barbers WHERE BarberID IN (SELECT BarberID FROM deleted);
END;

-- Привітання
CREATE FUNCTION Greeting (@Name NVARCHAR(100))
RETURNS NVARCHAR(150)
AS
BEGIN
    RETURN CONCAT('Hello, ', @Name, '!');
END;
GO

--Повернення інформації про поточну кількість хвилин
CREATE FUNCTION GetCurrentMinutes()
RETURNS INT
AS
BEGIN
    RETURN DATEPART(MINUTE, GETDATE());
END;
GO

-- Виконання
SELECT dbo.GetCurrentMinutes();

--Повернення інформації про поточний рік
CREATE FUNCTION GetCurrentYear()
RETURNS INT
AS
BEGIN
    RETURN YEAR(GETDATE());
END;
GO

-- Виконання
SELECT dbo.GetCurrentYear();

-- Перевіряє чи рік парний чи непарний
CREATE FUNCTION IsEvenYear()
RETURNS NVARCHAR(10)
AS
BEGIN
    RETURN CASE 
        WHEN YEAR(GETDATE()) % 2 = 0 THEN 'Even'
        ELSE 'Odd'
    END;
END;
GO

-- Виконання
SELECT dbo.IsEvenYear();

-- Перевіряє, чи є число простим
CREATE FUNCTION IsPrime(@Number INT)
RETURNS NVARCHAR(3)
AS
BEGIN
    IF @Number < 2 RETURN 'No';
    DECLARE @i INT = 2;
    WHILE @i <= SQRT(@Number)
    BEGIN
        IF @Number % @i = 0 RETURN 'No';
        SET @i = @i + 1;
    END;
    RETURN 'Yes';
END;
GO

-- Виконання
SELECT dbo.IsPrime(17); -- Просте число
SELECT dbo.IsPrime(20); -- Не просте число

-- Приймає 5 чисел і повертає суму мін і макс значення
CREATE FUNCTION MinMaxSum(@Num1 INT, @Num2 INT, @Num3 INT, @Num4 INT, @Num5 INT)
RETURNS INT
AS
BEGIN
    DECLARE @MinValue INT = (SELECT MIN(Value) FROM (VALUES (@Num1), (@Num2), (@Num3), (@Num4), (@Num5)) AS TempTable(Value));
    DECLARE @MaxValue INT = (SELECT MAX(Value) FROM (VALUES (@Num1), (@Num2), (@Num3), (@Num4), (@Num5)) AS TempTable(Value));
    RETURN @MinValue + @MaxValue;
END;
GO

-- Виконання
SELECT dbo.MinMaxSum(10, 20, 5, 15, 30); -- Результат: 5 + 30 = 35

-- Показує всі парні або непарні числа в діапазоні
CREATE FUNCTION GetEvenOrOddNumbers(@Start INT, @End INT, @Type NVARCHAR(5))
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @Result NVARCHAR(MAX) = '';
    DECLARE @i INT = @Start;

    WHILE @i <= @End
    BEGIN
        IF (@Type = 'Even' AND @i % 2 = 0) OR (@Type = 'Odd' AND @i % 2 <> 0)
        BEGIN
            SET @Result = @Result + CAST(@i AS NVARCHAR) + ', ';
        END;
        SET @i = @i + 1;
    END;

    RETURN LEFT(@Result, LEN(@Result) - 2); 
END;
GO

-- Виконання
SELECT dbo.GetEvenOrOddNumbers(1, 10, 'Even');
SELECT dbo.GetEvenOrOddNumbers(1, 10, 'Odd'); 

-- Hello, world!
CREATE PROCEDURE PrintHelloWorld
AS
BEGIN
    PRINT 'Hello, world!';
END;
GO

-- Виконання
EXEC PrintHelloWorld;

-- Повертає поточний час
CREATE PROCEDURE GetCurrentTime
AS
BEGIN
    SELECT CONVERT(VARCHAR, GETDATE(), 108) AS CurrentTime; -- Повертає у форматі HH:MM:SS
END;
GO

-- Виконання
EXEC GetCurrentTime;


-- Повертає поточну дату
CREATE PROCEDURE GetCurrentDate
AS
BEGIN
    SELECT CONVERT(VARCHAR, GETDATE(), 111) AS CurrentDate; -- Повертає у форматі YYYY/MM/DD
END;
GO

-- Виконання
EXEC GetCurrentDate;


-- Приймає 3 числа і повертає суму
CREATE PROCEDURE GetSumOfThreeNumbers
    @Num1 INT,
    @Num2 INT,
    @Num3 INT
AS
BEGIN
    SELECT @Num1 + @Num2 + @Num3 AS Sum;
END;
GO

-- Виконання
EXEC GetSumOfThreeNumbers 10, 20, 30; 

-- Приймає 3 числа і повертає середнє значення
CREATE PROCEDURE GetAverageOfThreeNumbers
    @Num1 FLOAT,
    @Num2 FLOAT,
    @Num3 FLOAT
AS
BEGIN
    SELECT (@Num1 + @Num2 + @Num3) / 3.0 AS Average;
END;
GO

-- Виконання
EXEC GetAverageOfThreeNumbers 10, 20, 30; 

-- Приймає 3 числа і повертає максимальне значення
CREATE PROCEDURE GetMaxOfThreeNumbers
    @Num1 INT,
    @Num2 INT,
    @Num3 INT
AS
BEGIN
    SELECT MAX(Value) AS MaxValue
    FROM (VALUES (@Num1), (@Num2), (@Num3)) AS TempTable(Value);
END;
GO

-- Виконання
EXEC GetMaxOfThreeNumbers 10, 50, 30; 

-- Приймає 3 числа і повертає мінімальне значення
CREATE PROCEDURE GetMinOfThreeNumbers
    @Num1 INT,
    @Num2 INT,
    @Num3 INT
AS
BEGIN
    SELECT MIN(Value) AS MinValue
    FROM (VALUES (@Num1), (@Num2), (@Num3)) AS TempTable(Value);
END;
GO

-- Виконання
EXEC GetMinOfThreeNumbers 10, 50, 30; 

-- Приймає число та символ, виводить рядок із символів
CREATE PROCEDURE PrintSymbolLine
    @Length INT,
    @Symbol CHAR(1)
AS
BEGIN
    DECLARE @Line NVARCHAR(MAX) = REPLICATE(@Symbol, @Length);
    PRINT @Line;
END;
GO

-- Виконання
EXEC PrintSymbolLine 5, '#';

-- Повертає факторіал числа
CREATE PROCEDURE GetFactorial
    @Number INT,
    @Result BIGINT OUTPUT
AS
BEGIN
    DECLARE @Fact BIGINT = 1;
    DECLARE @i INT = 1;

    WHILE @i <= @Number
    BEGIN
        SET @Fact = @Fact * @i;
        SET @i = @i + 1;
    END;

    SET @Result = @Fact;
END;
GO

-- Виконання
DECLARE @Result BIGINT;
EXEC GetFactorial 5, @Result OUTPUT;
SELECT @Result AS Factorial; 

-- Повертає число, зведене до ступеня
CREATE PROCEDURE GetPower
    @Base FLOAT,
    @Exponent INT,
    @Result FLOAT OUTPUT
AS
BEGIN
    SET @Result = POWER(@Base, @Exponent);
END;
GO

-- Виконання
DECLARE @Result FLOAT;
EXEC GetPower 2, 3, @Result OUTPUT;
SELECT @Result AS PowerResult; 








