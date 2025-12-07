// Commission calculation utility
// Matches the Dart implementation in fare_calculator.dart

const COMMISSION_RATE = 0.10; // 10%
const MINIMUM_COMMISSION = 100.0;

/**
 * Calculate commission for a booking
 * Uses hybrid commission model: 10% of final fare or minimum Rs. 100, whichever is higher
 * @param {number} finalFare - The final fare amount
 * @returns {Object} - Commission details
 */
export const calculateCommission = (finalFare) => {
    if (!finalFare || finalFare <= 0) {
        return {
            commission: 0,
            driverReceives: 0,
            percentage: 0
        };
    }

    const percentageCommission = finalFare * COMMISSION_RATE;
    const commission = percentageCommission < MINIMUM_COMMISSION
        ? MINIMUM_COMMISSION
        : percentageCommission;

    const driverReceives = finalFare - commission;

    return {
        commission: Math.round(commission * 100) / 100, // Round to 2 decimal places
        driverReceives: Math.round(driverReceives * 100) / 100,
        percentage: (commission / finalFare) * 100,
        commissionRate: COMMISSION_RATE,
        minimumCommission: MINIMUM_COMMISSION
    };
};

/**
 * Calculate commission for multiple bookings
 * @param {Array} bookings - Array of booking objects with offerFare or finalFare
 * @returns {Object} - Total commission statistics
 */
export const calculateTotalCommission = (bookings) => {
    const completedBookings = bookings.filter(b => b.status === 'completed');
    
    let totalCommission = 0;
    let totalRevenue = 0;
    let totalDriverReceives = 0;
    const commissionByBooking = [];

    completedBookings.forEach(booking => {
        const fare = parseFloat(booking.finalFare || booking.offerFare) || 0;
        if (fare > 0) {
            const commissionData = calculateCommission(fare);
            totalCommission += commissionData.commission;
            totalRevenue += fare;
            totalDriverReceives += commissionData.driverReceives;
            
            commissionByBooking.push({
                bookingId: booking.id,
                booking: booking,
                fare: fare,
                commission: commissionData.commission,
                driverReceives: commissionData.driverReceives,
                percentage: commissionData.percentage
            });
        }
    });

    return {
        totalCommission: Math.round(totalCommission * 100) / 100,
        totalRevenue: Math.round(totalRevenue * 100) / 100,
        totalDriverReceives: Math.round(totalDriverReceives * 100) / 100,
        bookingCount: completedBookings.length,
        averageCommission: completedBookings.length > 0 
            ? Math.round((totalCommission / completedBookings.length) * 100) / 100 
            : 0,
        commissionByBooking: commissionByBooking.sort((a, b) => b.commission - a.commission)
    };
};

