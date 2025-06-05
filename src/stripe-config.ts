export const products = {
  lifetime: {
    priceId: 'price_1RW02UInTpoMSXouhnQLA7Jn',
    name: 'Day of Timeline Beta - Lifetime Access',
    description: 'Lifetime access to Day of Timeline app including beta and all future updates',
    mode: 'payment' as const,
  },
  monthly: {
    priceId: 'price_1RW01zInTpoMSXoua1wZb9zY',
    name: 'Day of Timeline Beta - Monthly',
    description: 'Monthly subscription to Day of Timeline app with locked-in beta pricing',
    mode: 'subscription' as const,
  },
};